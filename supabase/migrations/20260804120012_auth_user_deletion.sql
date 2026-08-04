-- Preserve financial and household data when an auth user is deleted.

alter table public.households
  alter column created_by drop not null;

alter table public.households
  drop constraint if exists households_created_by_fkey,
  add constraint households_created_by_fkey
    foreign key (created_by)
    references auth.users(id)
    on delete set null;

alter table public.household_invites
  alter column created_by drop not null;

alter table public.household_invites
  drop constraint if exists household_invites_created_by_fkey,
  add constraint household_invites_created_by_fkey
    foreign key (created_by)
    references auth.users(id)
    on delete set null;

alter table public.receipts
  alter column uploaded_by drop not null;

alter table public.receipts
  drop constraint if exists receipts_uploaded_by_fkey,
  add constraint receipts_uploaded_by_fkey
    foreign key (uploaded_by)
    references auth.users(id)
    on delete set null;

alter table public.transactions
  alter column created_by drop not null;

alter table public.transactions
  drop constraint if exists transactions_created_by_fkey,
  add constraint transactions_created_by_fkey
    foreign key (created_by)
    references auth.users(id)
    on delete set null;
