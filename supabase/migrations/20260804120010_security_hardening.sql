-- Proteções descobertas pela auditoria multiusuário.

-- Impede hard-delete do último owner. O guard anterior cobre update/soft-delete.
create or replace function public.guard_last_owner_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.role = 'owner' and old.deleted_at is null then
    if (
      select count(*)
      from public.household_members
      where household_id = old.household_id
        and role = 'owner'
        and deleted_at is null
        and id <> old.id
    ) = 0 then
      raise exception 'a casa precisa de pelo menos um dono'
        using errcode = '23514';
    end if;
  end if;
  return old;
end
$$;

drop trigger if exists trg_last_owner_delete on public.household_members;
create trigger trg_last_owner_delete
  before delete on public.household_members
  for each row execute function public.guard_last_owner_delete();

-- O registro também precisa apontar para a pasta da própria casa.
alter table public.receipts
  add constraint receipts_storage_path_household
  check (storage_path like household_id::text || '/%') not valid;

alter table public.receipts
  validate constraint receipts_storage_path_household;

-- Receipts aceitam exatamente uma pasta (household) e um arquivo UUID.
create or replace function public.is_valid_receipt_storage_path(path text)
returns boolean
language sql
immutable
set search_path = public, storage, pg_temp
as $$
  select
    array_length(storage.foldername(path), 1) = 1
    and storage.filename(path) ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|pdf)$'
$$;

drop policy if exists receipts_select on storage.objects;
drop policy if exists receipts_insert on storage.objects;
drop policy if exists receipts_update on storage.objects;
drop policy if exists receipts_delete on storage.objects;

create policy receipts_select on storage.objects
for select to authenticated
using (
  bucket_id = 'receipts'
  and public.is_valid_receipt_storage_path(name)
  and public.is_household_member(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'receipts'
  and public.is_valid_receipt_storage_path(name)
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_update on storage.objects
for update to authenticated
using (
  bucket_id = 'receipts'
  and public.is_valid_receipt_storage_path(name)
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
)
with check (
  bucket_id = 'receipts'
  and public.is_valid_receipt_storage_path(name)
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'receipts'
  and public.is_valid_receipt_storage_path(name)
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);
