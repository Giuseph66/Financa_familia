-- =============================================================
-- 0004 — Planejamento e renda: orçamentos, metas, holerite,
--        acertos entre membros, dispositivos
-- =============================================================

-- -------------------------------------------------------------
-- budgets
-- -------------------------------------------------------------
create table public.budgets (
  id            uuid primary key,
  household_id  uuid not null references public.households(id) on delete cascade,

  -- 'household' = "a casa gasta no máximo R$ 1.200 em mercado"
  -- 'member'    = "eu gasto no máximo R$ 300 em besteira"
  scope         text not null default 'household' check (scope in ('household','member')),
  member_id     uuid references public.household_members(id) on delete cascade,
  category_id   uuid references public.categories(id) on delete cascade,  -- NULL = teto geral

  name          text,
  period        text not null default 'monthly' check (period in ('weekly','monthly','yearly')),
  amount_cents  bigint not null check (amount_cents > 0),
  starts_on     date not null,
  ends_on       date,
  rollover      boolean not null default false,
  alert_pct     smallint not null default 80 check (alert_pct between 1 and 200),

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  sync_version  bigint not null default nextval('public.sync_version_seq'),

  constraint budgets_member_scope check (scope <> 'member' or member_id is not null),
  constraint budgets_date_order   check (ends_on is null or ends_on >= starts_on)
);

create index budgets_sync on public.budgets (household_id, updated_at);
create index budgets_active on public.budgets (household_id, category_id)
  where deleted_at is null;

-- -------------------------------------------------------------
-- goals / goal_contributions
-- -------------------------------------------------------------
create table public.goals (
  id            uuid primary key,
  household_id  uuid not null references public.households(id) on delete cascade,
  scope         text not null default 'household' check (scope in ('household','member')),
  member_id     uuid references public.household_members(id) on delete cascade,
  account_id    uuid references public.accounts(id) on delete set null,
  name          text not null,
  target_cents  bigint not null check (target_cents > 0),
  target_date   date,
  icon          text not null default 'savings',
  color         text not null default '#2E7D32',
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  sync_version  bigint not null default nextval('public.sync_version_seq'),

  constraint goals_member_scope check (scope <> 'member' or member_id is not null)
);

-- O progresso é SUM(contributions). Não existe coluna current_cents:
-- valor materializado é a fonte nº 1 de divergência entre dispositivos.
create table public.goal_contributions (
  id              uuid primary key,
  household_id    uuid not null references public.households(id) on delete cascade,
  goal_id         uuid not null references public.goals(id) on delete cascade,
  transaction_id  uuid references public.transactions(id) on delete set null,
  amount_cents    bigint not null check (amount_cents <> 0),   -- negativo = resgate
  occurred_at     timestamptz not null default now(),
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  sync_version    bigint not null default nextval('public.sync_version_seq')
);

create index goals_sync on public.goals (household_id, updated_at);
create index goal_contributions_sync on public.goal_contributions (household_id, updated_at);
create index goal_contributions_by_goal on public.goal_contributions (goal_id)
  where deleted_at is null;

-- -------------------------------------------------------------
-- payslips — holerite brasileiro
-- -------------------------------------------------------------
-- Totalmente opcional. Quem só quer registrar "caiu R$ 3.200" faz um
-- lançamento de receita comum e nunca abre esta tela.
create table public.payslips (
  id                uuid primary key,
  household_id      uuid not null references public.households(id) on delete cascade,
  member_id         uuid not null references public.household_members(id) on delete cascade,
  account_id        uuid references public.accounts(id) on delete set null,
  transaction_id    uuid references public.transactions(id) on delete set null,
  receipt_id        uuid references public.receipts(id) on delete set null,

  employer          text,
  reference_month   date not null,          -- sempre dia 1 do mês de competência

  -- Separa 13º, férias e rescisão porque essas entradas distorcem a
  -- média mensal. O relatório de renda média exclui não-'monthly' por
  -- padrão, com um toggle.
  kind              text not null default 'monthly' check (kind in
                      ('monthly','thirteenth_1','thirteenth_2',
                       'vacation','termination','advance')),

  gross_cents       bigint not null default 0 check (gross_cents >= 0),
  deductions_cents  bigint not null default 0 check (deductions_cents >= 0),
  net_cents         bigint not null default 0,
  paid_on           date,
  notes             text,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  sync_version      bigint not null default nextval('public.sync_version_seq'),

  constraint payslips_reference_is_first_day check (extract(day from reference_month) = 1)
);

create index payslips_by_member
  on public.payslips (household_id, member_id, reference_month desc)
  where deleted_at is null;
create index payslips_sync on public.payslips (household_id, updated_at);

create table public.payslip_items (
  id            uuid primary key,
  household_id  uuid not null references public.households(id) on delete cascade,
  payslip_id    uuid not null references public.payslips(id) on delete cascade,

  -- 'info' são linhas que aparecem no holerite mas não entram na
  -- conta: base do FGTS, base do INSS, salário-família informativo.
  -- Sem isso o usuário tenta somar e não bate com o papel.
  kind          text not null check (kind in ('earning','deduction','info')),
  code          text,                       -- código da rubrica
  label         text not null,              -- "Adicional de insalubridade"
  amount_cents  bigint not null check (amount_cents >= 0),
  reference     text,                       -- "20%", "12h", "5 dias"
  sort_order    int not null default 0,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  sync_version  bigint not null default nextval('public.sync_version_seq')
);

create index payslip_items_by_payslip on public.payslip_items (payslip_id)
  where deleted_at is null;
create index payslip_items_sync on public.payslip_items (household_id, updated_at);

-- Recalcula os totais do holerite sempre que uma rubrica muda.
-- Aqui um trigger de agregação É seguro, ao contrário do caso dos
-- splits: o holerite é sempre editado inteiro numa tela só, e um
-- total temporariamente errado durante o sync se corrige sozinho no
-- próximo item que chegar.
create or replace function public.recalc_payslip_totals()
returns trigger language plpgsql as $$
declare
  v_payslip uuid := coalesce(new.payslip_id, old.payslip_id);
begin
  update public.payslips p set
    gross_cents = coalesce((
      select sum(amount_cents) from public.payslip_items
      where payslip_id = v_payslip and kind = 'earning' and deleted_at is null), 0),
    deductions_cents = coalesce((
      select sum(amount_cents) from public.payslip_items
      where payslip_id = v_payslip and kind = 'deduction' and deleted_at is null), 0)
  where p.id = v_payslip;

  update public.payslips
     set net_cents = gross_cents - deductions_cents
   where id = v_payslip;

  return null;
end $$;

create trigger trg_recalc_payslip
  after insert or update or delete on public.payslip_items
  for each row execute function public.recalc_payslip_totals();

-- -------------------------------------------------------------
-- settlements — acerto de contas entre membros
-- -------------------------------------------------------------
-- Fecha o ciclo do comparativo: o app aponta "você bancou R$ 200 a
-- mais das despesas comuns", ela transfere, o acerto fica registrado,
-- e o próximo período começa zerado.
create table public.settlements (
  id              uuid primary key,
  household_id    uuid not null references public.households(id) on delete cascade,
  from_member_id  uuid not null references public.household_members(id) on delete cascade,
  to_member_id    uuid not null references public.household_members(id) on delete cascade,
  amount_cents    bigint not null check (amount_cents > 0),
  period_start    date,
  period_end      date,
  settled_at      timestamptz,              -- NULL = pendente
  transaction_id  uuid references public.transactions(id) on delete set null,
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  sync_version    bigint not null default nextval('public.sync_version_seq'),

  constraint settlements_distinct_members check (from_member_id <> to_member_id)
);

create index settlements_sync on public.settlements (household_id, updated_at);

-- -------------------------------------------------------------
-- devices — do usuário, não da casa
-- -------------------------------------------------------------
create table public.devices (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  platform      text not null check (platform in ('android','ios','web')),
  model         text,
  os_version    text,
  app_version   text,
  push_token    text,
  last_sync_at  timestamptz,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  sync_version  bigint not null default nextval('public.sync_version_seq')
);

create index devices_by_user on public.devices (user_id);

select public.attach_sync_triggers(array[
  'budgets','goals','goal_contributions','payslips','payslip_items',
  'settlements','devices'
]);
