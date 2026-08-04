-- =============================================================
-- 0009 — Storage: buckets e políticas
-- =============================================================

-- -------------------------------------------------------------
-- Buckets
-- -------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('receipts', 'receipts', false, 10485760,      -- 10 MB
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('avatars',  'avatars',  true,  2097152,       -- 2 MB
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- O limite de 10 MB é generoso de propósito: o app já comprime a foto
-- para ~200 KB antes de subir (ver 11-recibos-ocr.md). O teto existe
-- para conter erro de código, não uso normal. Com a cota gratuita de
-- 1 GB, 200 KB por recibo dá cerca de 5.000 comprovantes.

-- -------------------------------------------------------------
-- receipts — privado, isolado por casa
-- -------------------------------------------------------------
-- Todo objeto vive em  {household_id}/{receipt_id}.jpg
--
-- O household_id ser a PRIMEIRA pasta do caminho não é organização
-- estética: é o mecanismo de autorização. storage.foldername(name)
-- devolve o caminho quebrado em array, e [1] é a casa dona do arquivo.
-- Se o app gravar em outro formato, estas políticas param de proteger.
--
-- try_uuid() em vez de cast direto porque o nome do objeto é
-- controlado pelo cliente: `'lixo'::uuid` derruba a avaliação da
-- política com erro em vez de simplesmente negar acesso.

create policy receipts_select on storage.objects
for select to authenticated
using (
  bucket_id = 'receipts'
  and public.is_household_member(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'receipts'
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_update on storage.objects
for update to authenticated
using (
  bucket_id = 'receipts'
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);

create policy receipts_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'receipts'
  and public.can_write_household(
        public.try_uuid((storage.foldername(name))[1]))
);

-- -------------------------------------------------------------
-- avatars — leitura pública, escrita só na própria pasta
-- -------------------------------------------------------------
-- Caminho: {user_id}/avatar.jpg
create policy avatars_select on storage.objects
for select to public
using (bucket_id = 'avatars');

create policy avatars_write on storage.objects
for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy avatars_update on storage.objects
for update to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy avatars_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
