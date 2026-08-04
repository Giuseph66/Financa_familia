-- =============================================================
-- 0003 — Núcleo: contas, categorias, estabelecimentos, lançamentos
-- =============================================================

-- -------------------------------------------------------------
-- accounts
-- -------------------------------------------------------------
create table public.accounts (
  id                     uuid primary key,
  household_id           uuid not null references public.households(id) on delete cascade,
  -- NULL = conta da casa, compartilhada
  owner_id               uuid references public.household_members(id) on delete set null,

  name                   text not null check (length(trim(name)) between 1 and 60),
  type                   text not null check (type in
                           ('checking','savings','cash','credit_card','benefit','investment','other')),
  institution            text,
  color                  text not null default '#6750A4',
  icon                   text not null default 'account_balance',

  opening_balance_cents  bigint not null default 0,

  -- Só cartão de crédito
  credit_limit_cents     bigint check (credit_limit_cents is null or credit_limit_cents >= 0),
  statement_closing_day  smallint check (statement_closing_day between 1 and 31),
  statement_due_day      smallint check (statement_due_day between 1 and 31),

  include_in_totals      boolean not null default true,
  visibility             text not null default 'household'
                           check (visibility in ('household','private')),
  sort_order             int not null default 0,
  archived_at            timestamptz,

  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz,
  sync_version           bigint not null default nextval('public.sync_version_seq'),

  -- Cartão sem dia de fechamento não consegue montar fatura.
  constraint accounts_credit_card_needs_cycle check (
    type <> 'credit_card' or statement_closing_day is not null
  )
);

create index accounts_by_household on public.accounts (household_id)
  where deleted_at is null;
create index accounts_sync on public.accounts (household_id, updated_at);

comment on column public.accounts.type is
  'benefit = vale-alimentação/refeição. Separado porque saldo de VR não é '
  'dinheiro livre e misturá-lo com a conta corrente distorce o disponível.';

-- -------------------------------------------------------------
-- category_templates — catálogo semente, NÃO sincronizado
-- -------------------------------------------------------------
-- Copiado para categories quando uma casa nasce. Ver comentário em
-- 02-modelo-de-dados.md sobre por que copiar em vez de compartilhar.
create table public.category_templates (
  key         text primary key,
  parent_key  text references public.category_templates(key),
  name        text not null,
  kind        text not null check (kind in ('expense','income')),
  icon        text not null,
  color       text not null,
  sort_order  int not null default 0
);

-- -------------------------------------------------------------
-- categories
-- -------------------------------------------------------------
create table public.categories (
  id            uuid primary key,
  household_id  uuid not null references public.households(id) on delete cascade,
  parent_id     uuid references public.categories(id) on delete set null,
  template_key  text,                    -- rastreia a origem no catálogo
  name          text not null check (length(trim(name)) between 1 and 40),
  kind          text not null check (kind in ('expense','income')),
  icon          text not null default 'category',
  color         text not null default '#8E8E93',
  is_system     boolean not null default false,
  sort_order    int not null default 0,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  sync_version  bigint not null default nextval('public.sync_version_seq')
);

create index categories_by_household on public.categories (household_id)
  where deleted_at is null;
create index categories_sync on public.categories (household_id, updated_at);
create unique index categories_template_unique
  on public.categories (household_id, template_key)
  where template_key is not null and deleted_at is null;

-- Hierarquia de no máximo dois níveis: uma subcategoria não pode ter
-- filhas. Três níveis viram árvore que ninguém navega no celular.
create or replace function public.enforce_category_depth()
returns trigger language plpgsql as $$
begin
  if new.parent_id is not null then
    if exists (select 1 from public.categories
               where id = new.parent_id and parent_id is not null) then
      raise exception 'categoria só aceita dois níveis de profundidade'
        using errcode = '23514';
    end if;
    if new.parent_id = new.id then
      raise exception 'categoria não pode ser pai de si mesma'
        using errcode = '23514';
    end if;
  end if;
  return new;
end $$;

create trigger trg_category_depth
  before insert or update of parent_id on public.categories
  for each row execute function public.enforce_category_depth();

-- -------------------------------------------------------------
-- merchants
-- -------------------------------------------------------------
-- A camada zero de inteligência do app, sem IA nenhuma: na terceira
-- vez que você digita "Carrefour", ele já sabe que é Mercado.
create table public.merchants (
  id                   uuid primary key,
  household_id         uuid not null references public.households(id) on delete cascade,
  name                 text not null,
  normalized_name      text not null,
  default_category_id  uuid references public.categories(id) on delete set null,
  default_account_id   uuid references public.accounts(id) on delete set null,
  cnpj                 text,
  use_count            int not null default 0,
  last_used_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz,
  sync_version         bigint not null default nextval('public.sync_version_seq')
);

create unique index merchants_unique_name
  on public.merchants (household_id, normalized_name)
  where deleted_at is null;
create index merchants_sync on public.merchants (household_id, updated_at);

-- normalized_name é sempre derivado, nunca enviado pelo cliente.
create or replace function public.set_merchant_normalized()
returns trigger language plpgsql as $$
begin
  new.normalized_name := public.normalize_name(new.name);
  if new.normalized_name is null then
    raise exception 'nome de estabelecimento vazio após normalização'
      using errcode = '23514';
  end if;
  return new;
end $$;

create trigger trg_merchant_normalize
  before insert or update of name on public.merchants
  for each row execute function public.set_merchant_normalized();

-- -------------------------------------------------------------
-- recurrences — declarada aqui por causa da FK em transactions
-- -------------------------------------------------------------
create table public.recurrences (
  id                  uuid primary key,
  household_id        uuid not null references public.households(id) on delete cascade,
  account_id          uuid references public.accounts(id) on delete set null,
  category_id         uuid references public.categories(id) on delete set null,
  member_id           uuid references public.household_members(id) on delete set null,

  name                text not null,
  kind                text not null check (kind in ('expense','income')),
  amount_cents        bigint not null check (amount_cents > 0),
  amount_is_estimate  boolean not null default false,

  frequency           text not null check (frequency in
                        ('weekly','biweekly','monthly','bimonthly',
                         'quarterly','semiannual','yearly')),
  interval_count      int not null default 1 check (interval_count between 1 and 60),
  day_of_month        smallint check (day_of_month between 1 and 31),
  weekday             smallint check (weekday between 0 and 6),
  next_due_on         date not null,
  ends_on             date,

  -- FALSE de propósito. Lançar automático parece conveniente e
  -- envenena os dados: a conta de luz veio R$ 40 mais cara, o app
  -- lançou o valor antigo, e o relatório vira ficção. O padrão é
  -- notificar e deixar confirmar com um toque.
  auto_post           boolean not null default false,
  remind_days_before  smallint not null default 2 check (remind_days_before between 0 and 30),
  paused_at           timestamptz,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  sync_version        bigint not null default nextval('public.sync_version_seq')
);

create index recurrences_due on public.recurrences (household_id, next_due_on)
  where deleted_at is null and paused_at is null;
create index recurrences_sync on public.recurrences (household_id, updated_at);

-- -------------------------------------------------------------
-- receipts — declarada aqui por causa da FK em transactions
-- -------------------------------------------------------------
create table public.receipts (
  id              uuid primary key,
  household_id    uuid not null references public.households(id) on delete cascade,
  uploaded_by     uuid not null references auth.users(id),

  -- O caminho COMEÇA pelo household_id. Isso não é estético: é o que
  -- permite a política de Storage autorizar por
  -- (storage.foldername(name))[1]. Ver 0011_storage.sql.
  storage_path    text not null,
  thumbnail_path  text,
  mime_type       text,
  byte_size       int,
  captured_at     timestamptz,

  ocr_status      text not null default 'pending'
                    check (ocr_status in ('pending','processing','done','failed','skipped')),
  ocr_engine      text,
  ocr_text        text,
  ocr_parsed      jsonb,
  ocr_confidence  numeric(4,3) check (ocr_confidence between 0 and 1),

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  sync_version    bigint not null default nextval('public.sync_version_seq')
);

create index receipts_sync on public.receipts (household_id, updated_at);

-- -------------------------------------------------------------
-- transactions — o centro do app
-- -------------------------------------------------------------
create table public.transactions (
  id                     uuid primary key,
  household_id           uuid not null references public.households(id) on delete cascade,
  account_id             uuid not null references public.accounts(id) on delete restrict,
  category_id            uuid references public.categories(id) on delete set null,
  member_id              uuid references public.household_members(id) on delete set null,
  created_by             uuid not null references auth.users(id),

  -- Quatro tipos, não três. Transferência entre contas próprias não é
  -- receita nem despesa: se fosse, o total do mês contaria dinheiro
  -- que só mudou de bolso. Uma transferência grava DUAS linhas com o
  -- mesmo transfer_group_id.
  kind                   text not null check (kind in
                           ('expense','income','transfer_out','transfer_in')),

  -- Sempre positivo. O sinal vem do kind, nunca do valor. Isso mata a
  -- classe de bug em que uma despesa é gravada positiva e some do
  -- relatório.
  amount_cents           bigint not null check (amount_cents > 0),

  -- Coluna gerada: qualquer soma vira SUM(signed_amount_cents), sem
  -- CASE espalhado por dez queries. Sendo gerada pelo banco, é
  -- impossível ficar dessincronizada do kind.
  signed_amount_cents    bigint generated always as (
                           case when kind in ('expense','transfer_out')
                                then -amount_cents else amount_cents end
                         ) stored,

  currency               text not null default 'BRL',
  occurred_at            timestamptz not null,
  description            text,
  merchant_id            uuid references public.merchants(id) on delete set null,
  payment_method         text check (payment_method in
                           ('pix','debit','credit','cash','boleto',
                            'transfer','benefit_card','other')),

  -- Compra em 12x gera 12 linhas, uma por mês, mesmo group_id. Não
  -- uma linha com valor cheio. É assim que a fatura funciona de
  -- verdade, e é a única forma de o mês futuro mostrar o
  -- comprometimento correto.
  installment_no         smallint check (installment_no >= 1),
  installment_total      smallint check (installment_total >= 1),
  installment_group_id   uuid,

  transfer_group_id      uuid,
  recurrence_id          uuid references public.recurrences(id) on delete set null,
  receipt_id             uuid references public.receipts(id) on delete set null,

  status                 text not null default 'cleared'
                           check (status in ('pending','cleared','reconciled')),
  visibility             text not null default 'household'
                           check (visibility in ('household','private')),
  is_reimbursable        boolean not null default false,
  notes                  text,
  tags                   text[] not null default '{}',

  -- Métrica de produto, não debug. Saber que 70% dos lançamentos vêm
  -- do widget e 5% do OCR é o que diz onde investir.
  source                 text not null default 'manual'
                           check (source in
                             ('manual','quick_add','widget','ocr',
                              'recurrence','import','ai')),

  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz,
  sync_version           bigint not null default nextval('public.sync_version_seq'),

  constraint transactions_installment_coherent check (
    (installment_no is null and installment_total is null and installment_group_id is null)
    or (installment_no is not null and installment_total is not null
        and installment_group_id is not null and installment_no <= installment_total)
  ),
  constraint transactions_transfer_needs_group check (
    kind not in ('transfer_out','transfer_in') or transfer_group_id is not null
  )
);

-- Índices. Sem estes a lista engasga já no primeiro ano.
create index transactions_by_date
  on public.transactions (household_id, occurred_at desc) where deleted_at is null;
create index transactions_by_account
  on public.transactions (account_id, occurred_at desc) where deleted_at is null;
create index transactions_by_category
  on public.transactions (household_id, category_id, occurred_at) where deleted_at is null;
create index transactions_by_member
  on public.transactions (household_id, member_id, occurred_at) where deleted_at is null;
create index transactions_installments
  on public.transactions (installment_group_id) where installment_group_id is not null;
create index transactions_transfers
  on public.transactions (transfer_group_id) where transfer_group_id is not null;
create index transactions_by_recurrence
  on public.transactions (recurrence_id) where recurrence_id is not null;

-- O índice mais importante do sistema: todo pull do sync é
-- WHERE household_id = ? AND updated_at > ?, em toda tabela, a cada
-- sincronização.
create index transactions_sync on public.transactions (household_id, updated_at);

-- Impede lançar em conta de outra casa. Uma FK composta é a única
-- forma de o banco garantir isso; sem ela, um cliente comprometido
-- poderia cruzar contas entre casas que ele acessa.
alter table public.accounts add constraint accounts_household_unique unique (id, household_id);
alter table public.transactions add constraint transactions_account_same_household
  foreign key (account_id, household_id)
  references public.accounts (id, household_id) on delete restrict;

-- -------------------------------------------------------------
-- transaction_splits
-- -------------------------------------------------------------
-- Dois usos, o mesmo mecanismo: dividir uma compra entre categorias
-- (R$ 200 de comida + R$ 50 de limpeza) ou entre membros (rateio).
create table public.transaction_splits (
  id              uuid primary key,
  household_id    uuid not null references public.households(id) on delete cascade,
  transaction_id  uuid not null references public.transactions(id) on delete cascade,
  category_id     uuid references public.categories(id) on delete set null,
  member_id       uuid references public.household_members(id) on delete set null,
  amount_cents    bigint not null check (amount_cents > 0),
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  sync_version    bigint not null default nextval('public.sync_version_seq')
);

create index splits_by_transaction on public.transaction_splits (transaction_id)
  where deleted_at is null;
create index splits_sync on public.transaction_splits (household_id, updated_at);

-- INVARIANTE, propositalmente NÃO imposta por trigger:
--   SUM(splits.amount_cents) = transaction.amount_cents
--
-- Um trigger de validação quebraria o sync. O pull traz a transação e
-- seus splits em ordem indeterminada, então o trigger dispararia com
-- os splits pela metade e rejeitaria dados perfeitamente válidos.
-- A validação mora em duas outras camadas: o app impede salvar
-- desbalanceado, e a view v_split_integrity lista divergências numa
-- tela de diagnóstico em Ajustes.

select public.attach_sync_triggers(array[
  'accounts','categories','merchants','recurrences','receipts',
  'transactions','transaction_splits'
]);
