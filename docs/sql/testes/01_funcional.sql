\set ON_ERROR_STOP on
\pset pager off

-- ============ 1. cadastro dispara o bootstrap ============
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'a@ex.com', '{"display_name":"Jesus"}'),
  ('22222222-2222-2222-2222-222222222222', 'b@ex.com', '{"display_name":"Maria"}'),
  ('33333333-3333-3333-3333-333333333333', 'c@ex.com', '{"display_name":"Filho"}');

select default_household_id as casa_a from public.profiles
  where id = '11111111-1111-1111-1111-111111111111' \gset
select default_household_id as casa_b from public.profiles
  where id = '22222222-2222-2222-2222-222222222222' \gset

select 'perfis criados' as teste, count(*)::text as obtido, '3' as esperado
  from public.profiles
union all select 'casas criadas', count(*)::text, '3' from public.households
union all select 'contas Carteira', count(*)::text, '3' from public.accounts
union all select 'categorias na casa A', count(*)::text, '81'
  from public.categories where household_id = :'casa_a'
union all select 'subcategorias na casa A', count(*)::text, '60'
  from public.categories where household_id = :'casa_a' and parent_id is not null;

-- ============ 2. convites ============
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select public.create_invite(:'casa_a', 'adult', 7) as cod_adulto \gset
  select public.create_invite(:'casa_a', 'teen', 7)  as cod_teen \gset
commit;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
  select 'convite aceito' as teste,
         (public.redeem_invite(:'cod_adulto') = :'casa_a')::text as obtido,
         't' as esperado
  union all
  select 'aceitar 2x e idempotente',
         (public.redeem_invite(:'cod_adulto') = :'casa_a')::text, 't';
commit;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
  select public.redeem_invite(:'cod_teen') as ignore \gset
commit;

select 'membros na casa A' as teste, count(*)::text as obtido, '3' as esperado
  from public.household_members where household_id = :'casa_a'
union all select 'cores de membro distintas', count(distinct color)::text, '3'
  from public.household_members where household_id = :'casa_a';

-- ============ 3. lançamentos, saldo, comparativo ============
select id as conta_a from public.accounts where household_id = :'casa_a' limit 1 \gset
select id as membro_j from public.household_members where household_id = :'casa_a'
  and user_id = '11111111-1111-1111-1111-111111111111' \gset
select id as membro_m from public.household_members where household_id = :'casa_a'
  and user_id = '22222222-2222-2222-2222-222222222222' \gset
select id as cat_mercado from public.categories where household_id = :'casa_a'
  and template_key = 'food.market' \gset

insert into public.accounts (id, household_id, name, type, opening_balance_cents)
  values (gen_random_uuid(), :'casa_a', 'Poupanca', 'savings', 0)
  returning id as conta_b \gset

insert into public.transactions
  (id, household_id, account_id, category_id, member_id, created_by,
   kind, amount_cents, occurred_at)
values
  (gen_random_uuid(), :'casa_a', :'conta_a', :'cat_mercado', :'membro_j',
   '11111111-1111-1111-1111-111111111111', 'expense', 3290, now()),
  (gen_random_uuid(), :'casa_a', :'conta_a', null, :'membro_j',
   '11111111-1111-1111-1111-111111111111', 'income', 420000, now()),
  (gen_random_uuid(), :'casa_a', :'conta_a', :'cat_mercado', :'membro_m',
   '22222222-2222-2222-2222-222222222222', 'expense', 15000, now());

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select public.create_transfer(:'casa_a', :'conta_a', :'conta_b',
                                50000, now(), :'membro_j', 'Guardar') as grupo \gset
commit;

select 'signed: despesa 3290' as teste, signed_amount_cents::text as obtido, '-3290' as esperado
  from public.transactions where amount_cents = 3290
union all select 'signed: receita 420000',
  signed_amount_cents::text, '420000' from public.transactions where amount_cents = 420000
union all select 'transferencia = 2 pernas',
  count(*)::text, '2' from public.transactions where transfer_group_id = :'grupo';

select 'saldo conta A' as teste, balance_cents::text as obtido, '351710' as esperado
  from public.v_account_balances where account_id = :'conta_a'
union all select 'saldo conta B (poupanca)', balance_cents::text, '50000'
  from public.v_account_balances where account_id = :'conta_b';

select 'comparativo ' || member_name as teste,
       'entrou=' || income_cents || ' saiu=' || expense_cents || ' saldo=' || net_cents as obtido,
       case member_name when 'Jesus' then 'entrou=420000 saiu=3290 saldo=416710'
                        else 'entrou=0 saiu=15000 saldo=-15000' end as esperado
  from public.v_member_month order by 1;

-- ============ 4. holerite: totais por trigger ============
insert into public.payslips (id, household_id, member_id, reference_month, employer)
  values (gen_random_uuid(), :'casa_a', :'membro_m',
          date_trunc('month', now())::date, 'Hospital')
  returning id as holerite \gset

insert into public.payslip_items
  (id, household_id, payslip_id, kind, label, amount_cents, reference)
values
  (gen_random_uuid(), :'casa_a', :'holerite', 'earning',   'Salario base',  320000, null),
  (gen_random_uuid(), :'casa_a', :'holerite', 'earning',   'Insalubridade',  26400, '20%'),
  (gen_random_uuid(), :'casa_a', :'holerite', 'deduction', 'INSS',           34853, null),
  (gen_random_uuid(), :'casa_a', :'holerite', 'deduction', 'IRRF',           11240, null),
  (gen_random_uuid(), :'casa_a', :'holerite', 'info',      'Base FGTS',     346400, null);

select 'holerite bruto' as teste, gross_cents::text as obtido, '346400' as esperado
  from public.payslips where id = :'holerite'
union all select 'holerite descontos', deductions_cents::text, '46093'
  from public.payslips where id = :'holerite'
union all select 'holerite liquido (info nao entra)', net_cents::text, '300307'
  from public.payslips where id = :'holerite';

-- ============ 5. sync_pull ============
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
  select 'sync_pull: transacoes' as teste,
         jsonb_array_length(public.sync_pull(:'casa_a')->'data'->'transactions')::text as obtido,
         '5' as esperado
  union all select 'sync_pull: categorias',
         jsonb_array_length(public.sync_pull(:'casa_a')->'data'->'categories')::text, '81'
  union all select 'sync_pull: tem cursor',
         (public.sync_pull(:'casa_a') ? 'cursor')::text, 't'
  union all select 'sync_pull: has_more falso',
         (public.sync_pull(:'casa_a')->>'has_more'), 'false';
commit;

-- ============ 6. proximo vencimento, casos de borda ============
select 'dia 31 -> abril (30 dias)' as teste,
       public.next_due_date('2026-03-31', 'monthly', 1, 31::smallint)::text as obtido,
       '2026-04-30' as esperado
union all select 'dia 31 -> fevereiro',
       public.next_due_date('2026-01-31', 'monthly', 1, 31::smallint)::text, '2026-02-28'
union all select '29/02 bissexto -> nao bissexto',
       public.next_due_date('2024-02-29', 'yearly', 1, 29::smallint)::text, '2025-02-28'
union all select 'semanal',
       public.next_due_date('2026-08-04', 'weekly', 1, null)::text, '2026-08-11';
