-- =============================================================
-- 0005 — Views de relatório
-- =============================================================
-- TODAS levam `security_invoker = on`.
--
-- Sem isso, a view roda com os privilégios de quem a CRIOU, e a RLS
-- de quem consulta é ignorada por completo. Uma view sem
-- security_invoker é a falha de segurança clássica do Supabase:
-- as tabelas ficam blindadas, a view vaza tudo entre casas.

-- -------------------------------------------------------------
-- v_account_balances — saldo atual por conta
-- -------------------------------------------------------------
create view public.v_account_balances
with (security_invoker = on) as
select
  a.id                as account_id,
  a.household_id,
  a.owner_id,
  a.name,
  a.type,
  a.include_in_totals,
  a.opening_balance_cents
    + coalesce(sum(t.signed_amount_cents) filter (where t.status <> 'pending'), 0)
                      as balance_cents,
  -- Inclui lançamentos ainda não confirmados: é o "quanto vai sobrar
  -- se tudo que está no ar acontecer".
  a.opening_balance_cents
    + coalesce(sum(t.signed_amount_cents), 0)
                      as projected_balance_cents,
  count(t.id)         as transaction_count,
  max(t.occurred_at)  as last_transaction_at
from public.accounts a
left join public.transactions t
  on t.account_id = a.id and t.deleted_at is null
where a.deleted_at is null
group by a.id, a.household_id, a.owner_id, a.name, a.type,
         a.include_in_totals, a.opening_balance_cents;

-- -------------------------------------------------------------
-- v_member_month — O COMPARATIVO DO CASAL
-- -------------------------------------------------------------
-- A view que justifica ter escolhido Postgres. Responde a pergunta
-- central do produto — "como estamos um em relação ao outro?" — numa
-- query só. Em Firestore isso seria leitura da coleção inteira no
-- cliente e soma em Dart.
--
-- Lançamentos 'private' ficam de fora: o comparativo é sobre a vida
-- compartilhada, e presente de aniversário não precisa aparecer nele.
create view public.v_member_month
with (security_invoker = on) as
select
  t.household_id,
  t.member_id,
  m.display_name                                as member_name,
  m.color                                       as member_color,
  date_trunc('month', t.occurred_at)::date      as month,
  coalesce(sum(t.amount_cents) filter (where t.kind = 'income'), 0)   as income_cents,
  coalesce(sum(t.amount_cents) filter (where t.kind = 'expense'), 0)  as expense_cents,
  coalesce(sum(t.signed_amount_cents)
           filter (where t.kind in ('income','expense')), 0)          as net_cents,
  count(*) filter (where t.kind = 'expense')                          as expense_count
from public.transactions t
join public.household_members m on m.id = t.member_id
where t.deleted_at is null
  and t.visibility = 'household'
  and t.kind in ('income','expense')
group by t.household_id, t.member_id, m.display_name, m.color,
         date_trunc('month', t.occurred_at);

-- -------------------------------------------------------------
-- v_category_month — gasto por categoria e mês
-- -------------------------------------------------------------
create view public.v_category_month
with (security_invoker = on) as
select
  t.household_id,
  t.category_id,
  c.name                                    as category_name,
  c.icon                                    as category_icon,
  c.color                                   as category_color,
  c.kind                                    as category_kind,
  c.parent_id,
  date_trunc('month', t.occurred_at)::date  as month,
  sum(t.amount_cents)                       as total_cents,
  count(*)                                  as entry_count,
  round(100.0 * sum(t.amount_cents) / nullif(
    sum(sum(t.amount_cents)) over (
      partition by t.household_id, date_trunc('month', t.occurred_at), t.kind
    ), 0), 2)                               as pct_of_month
from public.transactions t
left join public.categories c on c.id = t.category_id
where t.deleted_at is null
  and t.kind in ('income','expense')
group by t.household_id, t.category_id, c.name, c.icon, c.color, c.kind,
         c.parent_id, date_trunc('month', t.occurred_at), t.kind;

-- -------------------------------------------------------------
-- v_budget_progress — orçado vs realizado no período corrente
-- -------------------------------------------------------------
create view public.v_budget_progress
with (security_invoker = on) as
with period as (
  select
    b.*,
    case b.period
      when 'weekly'  then date_trunc('week',  now())::date
      when 'monthly' then date_trunc('month', now())::date
      when 'yearly'  then date_trunc('year',  now())::date
    end as period_start,
    case b.period
      when 'weekly'  then (date_trunc('week',  now()) + interval '1 week')::date
      when 'monthly' then (date_trunc('month', now()) + interval '1 month')::date
      when 'yearly'  then (date_trunc('year',  now()) + interval '1 year')::date
    end as period_end
  from public.budgets b
  where b.deleted_at is null
    and b.starts_on <= current_date
    and (b.ends_on is null or b.ends_on >= current_date)
)
select
  p.id            as budget_id,
  p.household_id,
  p.scope,
  p.member_id,
  p.category_id,
  p.name,
  p.period,
  p.amount_cents,
  p.alert_pct,
  p.period_start,
  p.period_end,
  coalesce(sum(t.amount_cents), 0)                                  as spent_cents,
  p.amount_cents - coalesce(sum(t.amount_cents), 0)                 as remaining_cents,
  round(100.0 * coalesce(sum(t.amount_cents), 0) / p.amount_cents, 1) as pct_used,
  (p.period_end - current_date)                                     as days_left
from period p
left join public.transactions t
  on  t.household_id = p.household_id
  and t.deleted_at is null
  and t.kind = 'expense'
  and t.occurred_at >= p.period_start
  and t.occurred_at <  p.period_end
  and (p.category_id is null or t.category_id = p.category_id)
  and (p.scope = 'household' or t.member_id = p.member_id)
group by p.id, p.household_id, p.scope, p.member_id, p.category_id, p.name,
         p.period, p.amount_cents, p.alert_pct, p.period_start, p.period_end;

-- -------------------------------------------------------------
-- v_credit_card_bill — fatura por ciclo
-- -------------------------------------------------------------
-- Cartão tem semântica própria: o que interessa é a fatura do ciclo,
-- não o mês-calendário. Uma compra em 28/01 com fechamento no dia 25
-- pertence à fatura de fevereiro.
-- O ciclo é calculado numa subquery e agrupado pelo alias. Escrever a
-- expressão direto no SELECT e agrupar por posição (`group by ..., 2`)
-- NÃO funciona: a posição aponta para a coluna daquele índice na lista
-- de saída, não para a expressão pretendida, e o Postgres rejeita com
-- "column t.occurred_at must appear in the GROUP BY clause".
create view public.v_credit_card_bill
with (security_invoker = on) as
select
  x.account_id,
  x.household_id,
  x.account_name,
  x.bill_month,
  -- Fatura é dívida: inverte o sinal para exibir positivo.
  sum(x.signed_amount_cents) * -1  as total_cents,
  count(*)                         as entry_count,
  min(x.occurred_at)               as first_entry_at,
  max(x.occurred_at)               as last_entry_at
from (
  select
    a.id            as account_id,
    a.household_id,
    a.name          as account_name,
    t.occurred_at,
    t.signed_amount_cents,
    -- Compra depois do fechamento entra no ciclo seguinte: uma compra
    -- em 28/01 num cartão que fecha dia 25 pertence à fatura de
    -- fevereiro.
    (date_trunc('month',
       t.occurred_at
       + case when extract(day from t.occurred_at) > a.statement_closing_day
              then interval '1 month' else interval '0 month' end
     ))::date       as bill_month
  from public.accounts a
  join public.transactions t
    on t.account_id = a.id and t.deleted_at is null
  where a.type = 'credit_card'
    and a.deleted_at is null
    and a.statement_closing_day is not null
) x
group by x.account_id, x.household_id, x.account_name, x.bill_month;

-- -------------------------------------------------------------
-- v_upcoming_bills — contas fixas dos próximos 30 dias
-- -------------------------------------------------------------
create view public.v_upcoming_bills
with (security_invoker = on) as
select
  r.id            as recurrence_id,
  r.household_id,
  r.name,
  r.kind,
  r.amount_cents,
  r.amount_is_estimate,
  r.next_due_on,
  r.account_id,
  r.category_id,
  r.member_id,
  r.auto_post,
  (r.next_due_on - current_date) as days_until,
  (r.next_due_on < current_date) as is_overdue
from public.recurrences r
where r.deleted_at is null
  and r.paused_at is null
  and (r.ends_on is null or r.ends_on >= current_date)
  and r.next_due_on <= current_date + interval '30 days';

-- -------------------------------------------------------------
-- v_household_net_worth — patrimônio da casa
-- -------------------------------------------------------------
create view public.v_household_net_worth
with (security_invoker = on) as
select
  b.household_id,
  sum(b.balance_cents) filter (where a.type <> 'credit_card')  as assets_cents,
  -sum(b.balance_cents) filter (where a.type = 'credit_card')  as liabilities_cents,
  sum(b.balance_cents)                                         as net_worth_cents
from public.v_account_balances b
join public.accounts a on a.id = b.account_id
where a.include_in_totals and a.deleted_at is null
group by b.household_id;

-- -------------------------------------------------------------
-- v_split_integrity — diagnóstico
-- -------------------------------------------------------------
-- Lista lançamentos cujos splits não fecham com o total. Alimenta uma
-- tela em Ajustes › Diagnóstico. Em operação normal vem vazia; se vier
-- linha, houve bug de escrita ou conflito de sync mal resolvido.
create view public.v_split_integrity
with (security_invoker = on) as
select
  t.id            as transaction_id,
  t.household_id,
  t.occurred_at,
  t.description,
  t.amount_cents,
  sum(s.amount_cents)                    as split_total_cents,
  t.amount_cents - sum(s.amount_cents)   as difference_cents
from public.transactions t
join public.transaction_splits s
  on s.transaction_id = t.id and s.deleted_at is null
where t.deleted_at is null
group by t.id, t.household_id, t.occurred_at, t.description, t.amount_cents
having sum(s.amount_cents) <> t.amount_cents;

-- -------------------------------------------------------------
-- v_member_shared_contribution — quem bancou quanto da casa
-- -------------------------------------------------------------
-- Base do acerto de contas. Considera só despesas em contas
-- COMPARTILHADAS (accounts.owner_id is null) ou marcadas como
-- reembolsáveis — o que cada um gasta na conta própria com coisa
-- própria não entra no rateio.
create view public.v_member_shared_contribution
with (security_invoker = on) as
select
  t.household_id,
  t.member_id,
  m.display_name                            as member_name,
  date_trunc('month', t.occurred_at)::date  as month,
  sum(t.amount_cents)                       as paid_cents
from public.transactions t
join public.household_members m on m.id = t.member_id
left join public.accounts a on a.id = t.account_id
where t.deleted_at is null
  and t.kind = 'expense'
  and t.visibility = 'household'
  and (a.owner_id is null or t.is_reimbursable)
group by t.household_id, t.member_id, m.display_name,
         date_trunc('month', t.occurred_at);
