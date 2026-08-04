\pset pager off
\set ON_ERROR_STOP off

\echo '===== 1. usuario SEM casa nenhuma le ZERO de tudo ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000"}';
  select 'transactions' as tabela, count(*)::text as lidas, '0' as esperado from public.transactions
  union all select 'accounts',          count(*)::text, '0' from public.accounts
  union all select 'categories',        count(*)::text, '0' from public.categories
  union all select 'households',        count(*)::text, '0' from public.households
  union all select 'household_members', count(*)::text, '0' from public.household_members
  union all select 'payslips',          count(*)::text, '0' from public.payslips
  union all select 'payslip_items',     count(*)::text, '0' from public.payslip_items
  union all select 'budgets',           count(*)::text, '0' from public.budgets
  union all select 'receipts',          count(*)::text, '0' from public.receipts
  union all select 'household_invites', count(*)::text, '0' from public.household_invites
  union all select 'v_member_month',    count(*)::text, '0' from public.v_member_month
  union all select 'v_account_balances',count(*)::text, '0' from public.v_account_balances;
commit;

\echo ''
\echo '===== 2. Jesus (dono) ve a casa dele ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select 'transacoes visiveis' as teste, count(*)::text as obtido, '5' as esperado
    from public.transactions
  union all select 'holerites visiveis', count(*)::text, '1' from public.payslips
  union all select 'membros visiveis',   count(*)::text, '3' from public.household_members;
commit;

\echo ''
\echo '===== 3. Filho (teen) NAO ve holerite nem gasto dos outros ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
  select 'holerites visiveis' as teste, count(*)::text as obtido, '0' as esperado
    from public.payslips
  union all select 'rubricas visiveis', count(*)::text, '0' from public.payslip_items
  union all select 'transacoes visiveis (nenhuma e dele)', count(*)::text, '0'
    from public.transactions;
commit;

\echo ''
\echo '===== 4. teen tentando se promover a owner (DEVE FALHAR) ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
  update public.household_members set role = 'owner' where user_id = auth.uid();
rollback;

\echo ''
\echo '===== 5. teen lancando no nome de outro membro (DEVE FALHAR) ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
  insert into public.transactions
    (id, household_id, account_id, member_id, created_by, kind, amount_cents, occurred_at)
  select gen_random_uuid(), m.household_id, a.id, m2.id, auth.uid(), 'expense', 999, now()
  from public.household_members m
  join public.accounts a on a.household_id = m.household_id
  join public.household_members m2
    on m2.household_id = m.household_id and m2.user_id <> auth.uid()
  where m.user_id = auth.uid() limit 1;
rollback;

\echo ''
\echo '===== 6. remover o ultimo dono da casa (DEVE FALHAR) ====='
begin;
  update public.household_members set deleted_at = now()
  where role = 'owner'
    and household_id = (select default_household_id from public.profiles
                        where id = '22222222-2222-2222-2222-222222222222');
rollback;

\echo ''
\echo '===== 7. Maria tentando ler a casa PESSOAL do Jesus (nao e membro) ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
  select 'casas visiveis para Maria' as teste, count(*)::text as obtido, '2' as esperado
    from public.households;
commit;

\echo ''
\echo '===== 8. lancamento private so aparece para quem criou ====='
begin;
  insert into public.transactions
    (id, household_id, account_id, member_id, created_by, kind, amount_cents,
     occurred_at, visibility, description)
  select gen_random_uuid(), m.household_id, a.id, m.id,
         '11111111-1111-1111-1111-111111111111', 'expense', 8800, now(),
         'private', 'presente surpresa'
  from public.household_members m
  join public.accounts a on a.household_id = m.household_id
  where m.user_id = '11111111-1111-1111-1111-111111111111' limit 1;
commit;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select 'Jesus ve o proprio private' as teste, count(*)::text as obtido, '1' as esperado
    from public.transactions where visibility = 'private';
commit;
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
  select 'Maria NAO ve o private do Jesus' as teste, count(*)::text as obtido, '0' as esperado
    from public.transactions where visibility = 'private';
commit;

\echo ''
\echo '===== 9. private fora do comparativo ====='
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select 'despesa do Jesus no comparativo' as teste, expense_cents::text as obtido,
         '3290 (private de 8800 fora)' as esperado
    from public.v_member_month
    where member_name = 'Jesus';
commit;

\echo ''
\echo '===== 10. Storage isolado por casa ====='
-- No Supabase real o papel authenticated já tem estes grants; o stub
-- local não, daí a linha abaixo.
grant select, insert, update, delete on storage.objects to authenticated;

insert into storage.objects (bucket_id, name)
  select 'receipts', default_household_id || '/do-jesus.jpg' from public.profiles
  where id = '11111111-1111-1111-1111-111111111111';
insert into storage.objects (bucket_id, name)
  select 'receipts', default_household_id || '/da-maria.jpg' from public.profiles
  where id = '22222222-2222-2222-2222-222222222222';
-- Caminho com lixo no lugar do uuid: try_uuid() precisa devolver NULL
-- em vez de derrubar a avaliação da política com erro.
insert into storage.objects (bucket_id, name) values ('receipts', 'lixo/x.jpg');

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  -- Jesus é membro só da casa compartilhada: vê o recibo dela e NÃO vê
  -- o da casa pessoal da Maria. É esta linha que prova o isolamento.
  select 'Jesus ve so o recibo da casa dele' as teste,
         count(*)::text as obtido, '1' as esperado
    from storage.objects where bucket_id = 'receipts';
commit;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
  -- Maria pertence a DUAS casas (a pessoal dela e a compartilhada),
  -- então 2 é o resultado correto.
  select 'Maria ve os recibos das 2 casas dela' as teste,
         count(*)::text as obtido, '2' as esperado
    from storage.objects where bucket_id = 'receipts';
commit;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000"}';
  select 'usuario sem casa ve zero recibos' as teste,
         count(*)::text as obtido, '0' as esperado
    from storage.objects where bucket_id = 'receipts';
commit;
