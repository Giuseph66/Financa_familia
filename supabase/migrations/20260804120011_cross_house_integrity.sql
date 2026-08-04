-- =============================================================
-- Integridade entre casas: referências cruzadas e casa padrão
-- =============================================================

-- Uma FK composta precisa de uma chave única correspondente no lado
-- referenciado. Os IDs já são PKs; estas chaves não alteram os dados e
-- tornam explícita a associação entre o registro e a sua casa.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.household_members'::regclass
      and conname = 'household_members_id_household_unique'
  ) then
    alter table public.household_members
      add constraint household_members_id_household_unique
      unique (id, household_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.categories'::regclass
      and conname = 'categories_id_household_unique'
  ) then
    alter table public.categories
      add constraint categories_id_household_unique
      unique (id, household_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.receipts'::regclass
      and conname = 'receipts_id_household_unique'
  ) then
    alter table public.receipts
      add constraint receipts_id_household_unique
      unique (id, household_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.merchants'::regclass
      and conname = 'merchants_id_household_unique'
  ) then
    alter table public.merchants
      add constraint merchants_id_household_unique
      unique (id, household_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.recurrences'::regclass
      and conname = 'recurrences_id_household_unique'
  ) then
    alter table public.recurrences
      add constraint recurrences_id_household_unique
      unique (id, household_id);
  end if;
end
$$;

-- NOT VALID é intencional: permite aplicar a migration mesmo se houver
-- legado inconsistente, mas valida toda inserção e atualização futura.
-- SET NULL altera apenas a referência; household_id permanece intacto.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_member_same_household'
  ) then
    alter table public.transactions
      add constraint transactions_member_same_household
      foreign key (member_id, household_id)
      references public.household_members (id, household_id)
      on delete set null (member_id)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_category_same_household'
  ) then
    alter table public.transactions
      add constraint transactions_category_same_household
      foreign key (category_id, household_id)
      references public.categories (id, household_id)
      on delete set null (category_id)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_receipt_same_household'
  ) then
    alter table public.transactions
      add constraint transactions_receipt_same_household
      foreign key (receipt_id, household_id)
      references public.receipts (id, household_id)
      on delete set null (receipt_id)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_merchant_same_household'
  ) then
    alter table public.transactions
      add constraint transactions_merchant_same_household
      foreign key (merchant_id, household_id)
      references public.merchants (id, household_id)
      on delete set null (merchant_id)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_recurrence_same_household'
  ) then
    alter table public.transactions
      add constraint transactions_recurrence_same_household
      foreign key (recurrence_id, household_id)
      references public.recurrences (id, household_id)
      on delete set null (recurrence_id)
      not valid;
  end if;
end
$$;

-- A casa padrão pertence ao próprio perfil e precisa de membership
-- ativo. SECURITY DEFINER evita que RLS esconda o membership durante a
-- checagem; o search_path fixo impede resolução por schema controlável.
create or replace function public.guard_profile_default_household()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.default_household_id is not null
     and not exists (
       select 1
       from public.household_members hm
       where hm.household_id = new.default_household_id
         and hm.user_id = new.id
         and hm.deleted_at is null
     ) then
    raise exception
      'default_household_id precisa apontar para uma casa com membership ativo do perfil'
      using errcode = '23514';
  end if;

  return new;
end
$$;

-- handle_new_user insere o membership antes deste UPDATE do profile.
drop trigger if exists trg_profile_default_household_guard on public.profiles;
create trigger trg_profile_default_household_guard
  before insert or update of id, default_household_id on public.profiles
  for each row execute function public.guard_profile_default_household();
