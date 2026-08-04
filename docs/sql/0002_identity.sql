-- =============================================================
-- 0002 — Identidade: perfis, casas, membros, convites
-- =============================================================

-- -------------------------------------------------------------
-- profiles
-- -------------------------------------------------------------
create table public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  display_name          text not null,
  avatar_url            text,
  locale                text not null default 'pt_BR',
  currency              text not null default 'BRL',
  default_household_id  uuid,
  onboarded_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  sync_version          bigint not null default nextval('public.sync_version_seq')
);

comment on table public.profiles is
  'Extensão de auth.users. Criada por trigger no cadastro — o app nunca insere aqui.';

-- -------------------------------------------------------------
-- households
-- -------------------------------------------------------------
create table public.households (
  id               uuid primary key,
  name             text not null check (length(trim(name)) between 1 and 60),
  created_by       uuid not null references auth.users(id),
  currency         text not null default 'BRL',
  -- Dia em que o "mês financeiro" começa. Quem recebe dia 5 pensa o
  -- mês de 5 a 4. Teto 28 porque 29/30/31 não existem em todo mês.
  month_start_day  smallint not null default 1 check (month_start_day between 1 and 28),
  icon             text not null default 'home',
  color            text not null default '#6750A4',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  sync_version     bigint not null default nextval('public.sync_version_seq')
);

-- -------------------------------------------------------------
-- household_members
-- -------------------------------------------------------------
create table public.household_members (
  id                uuid primary key,
  household_id      uuid not null references public.households(id) on delete cascade,

  -- Anulável de propósito: habilita o "membro-fantasma". Um filho
  -- pequeno ou alguém sem smartphone existe como membro, recebe
  -- gastos atribuídos e aparece no comparativo, sem conta de login.
  -- Vira usuário real depois preenchendo este campo, sem perder
  -- histórico nenhum.
  user_id           uuid references auth.users(id) on delete set null,

  role              text not null default 'adult'
                      check (role in ('owner','adult','teen','viewer')),
  display_name      text not null,
  color             text not null default '#6750A4',
  avatar_emoji      text,
  -- Percentual de rateio padrão das despesas comuns
  income_share_pct  numeric(5,2) check (income_share_pct between 0 and 100),
  joined_at         timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  sync_version      bigint not null default nextval('public.sync_version_seq')
);

-- Um usuário entra uma vez só por casa. Índice parcial porque
-- membros-fantasma têm user_id NULL e vários NULLs devem coexistir.
create unique index household_members_unique_user
  on public.household_members (household_id, user_id)
  where user_id is not null and deleted_at is null;

create index household_members_by_user on public.household_members (user_id)
  where deleted_at is null;

-- Toda casa precisa de pelo menos um owner. Garantido em
-- 0009_rpc.sql, no fluxo de remoção de membro.

-- -------------------------------------------------------------
-- household_invites
-- -------------------------------------------------------------
create table public.household_invites (
  id            uuid primary key,
  household_id  uuid not null references public.households(id) on delete cascade,
  -- Alfabeto sem I, O, 0 e 1: o código é lido em voz alta ou digitado
  -- do print, e essas quatro se confundem.
  code          text not null unique,
  role          text not null default 'adult'
                  check (role in ('adult','teen','viewer')),
  created_by    uuid not null references auth.users(id),
  expires_at    timestamptz not null default (now() + interval '7 days'),
  max_uses      int not null default 1 check (max_uses > 0),
  uses          int not null default 0,
  revoked_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  sync_version  bigint not null default nextval('public.sync_version_seq')
);

create index household_invites_by_household on public.household_invites (household_id);

-- profiles.default_household_id só pode apontar para casa existente.
-- FK adicionada depois porque households nasce depois de profiles.
alter table public.profiles
  add constraint profiles_default_household_fk
  foreign key (default_household_id) references public.households(id) on delete set null;

-- =============================================================
-- Funções auxiliares de autorização
-- =============================================================
-- ATENÇÃO, ARMADILHA CENTRAL DO SUPABASE:
--
-- A política de RLS de household_members precisa consultar
-- household_members para saber se você é membro. Escrita direto no
-- USING, isso é recursão infinita e o Postgres aborta com
-- "infinite recursion detected in policy for relation".
--
-- SECURITY DEFINER quebra o ciclo: a função roda com os privilégios
-- do dono, que ignora RLS, então a consulta interna não reativa a
-- política. Por isso TODA política deste projeto passa por estas
-- funções em vez de fazer subquery direta.
--
-- SECURITY DEFINER sem search_path fixo é vetor de escalonamento de
-- privilégio: um schema malicioso no caminho de busca sequestraria a
-- resolução de nomes. Daí o `set search_path` em todas.
-- =============================================================

create or replace function public.current_household_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select household_id
  from public.household_members
  where user_id = auth.uid() and deleted_at is null;
$$;

create or replace function public.is_household_member(h uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.household_members
    where household_id = h and user_id = auth.uid() and deleted_at is null
  );
$$;

create or replace function public.household_role(h uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role from public.household_members
  where household_id = h and user_id = auth.uid() and deleted_at is null
  limit 1;
$$;

-- Quem pode criar e editar dados livremente na casa.
-- viewer não escreve nada; teen só mexe no que é dele (tratado
-- caso a caso nas políticas de transactions).
create or replace function public.can_write_household(h uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.household_members
    where household_id = h and user_id = auth.uid()
      and deleted_at is null and role in ('owner','adult')
  );
$$;

create or replace function public.is_household_owner(h uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.household_members
    where household_id = h and user_id = auth.uid()
      and deleted_at is null and role = 'owner'
  );
$$;

-- O household_members.id do usuário atual naquela casa. Usado para
-- restringir o teen aos próprios lançamentos.
create or replace function public.current_member_id(h uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from public.household_members
  where household_id = h and user_id = auth.uid() and deleted_at is null
  limit 1;
$$;

revoke all on function
  public.current_household_ids(),
  public.is_household_member(uuid),
  public.household_role(uuid),
  public.can_write_household(uuid),
  public.is_household_owner(uuid),
  public.current_member_id(uuid)
from public, anon;

grant execute on function
  public.current_household_ids(),
  public.is_household_member(uuid),
  public.household_role(uuid),
  public.can_write_household(uuid),
  public.is_household_owner(uuid),
  public.current_member_id(uuid)
to authenticated;

select public.attach_sync_triggers(array[
  'profiles','households','household_members','household_invites'
]);
