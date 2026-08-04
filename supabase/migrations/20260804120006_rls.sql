-- =============================================================
-- 0006 — Row Level Security
-- =============================================================
-- Este arquivo é o que de fato protege os dados. A publishable key
-- fica no aplicativo e é considerada pública; qualquer pessoa pode
-- extraí-la do APK e chamar a API REST direto com curl. O que impede
-- alguém de ler o dinheiro da sua casa é exclusivamente o que está
-- escrito aqui.
--
-- Toda política passa pelas funções SECURITY DEFINER de
-- 0002_identity.sql. Não escreva subquery direta em household_members
-- dentro de uma política: isso causa recursão infinita.

-- -------------------------------------------------------------
-- Ligar RLS em tudo, e negar anon por padrão
-- -------------------------------------------------------------
-- NÃO usamos FORCE ROW LEVEL SECURITY, e a razão é importante.
--
-- FORCE sujeita também o DONO da tabela às políticas. Isso quebraria
-- todas as funções SECURITY DEFINER deste projeto, que dependem
-- justamente de o dono não estar sujeito à RLS:
--
--   * is_household_member() e as demais auxiliares leem
--     household_members. Com FORCE, a leitura reativaria a política
--     de household_members, que chama is_household_member() — a
--     recursão infinita que essas funções existem para evitar.
--   * handle_new_user() insere em profiles, que não tem política de
--     INSERT (perfil nasce por trigger, nunca pelo app). Com FORCE, o
--     cadastro de qualquer usuário falharia.
--   * purge_deleted() apaga de 14 tabelas que só têm política de
--     DELETE para o owner da casa.
--
-- O risco que FORCE cobriria é testar como dono e concluir
-- erradamente que a política funciona. Isso é resolvido de outra
-- forma: TODO teste de RLS deste projeto usa
-- `set local role authenticated` + `set local request.jwt.claims`,
-- que assume um papel comum e exercita as políticas de verdade.
-- Ver 05-rls-seguranca.md.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','households','household_members','household_invites',
    'accounts','categories','merchants','transactions','transaction_splits',
    'budgets','goals','goal_contributions','recurrences',
    'payslips','payslip_items','receipts','settlements','devices',
    'category_templates'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    -- anon nunca lê nada: todo acesso exige usuário autenticado.
    execute format('revoke all on public.%I from anon', t);
    execute format(
      'grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- =============================================================
-- profiles
-- =============================================================
-- Você lê o seu perfil e o de quem divide casa com você (para exibir
-- nome e avatar nos relatórios). Não lê mais ninguém.
create policy profiles_select on public.profiles for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.household_members me
    join public.household_members other on other.household_id = me.household_id
    where me.user_id = auth.uid() and me.deleted_at is null
      and other.user_id = public.profiles.id and other.deleted_at is null
  )
);

create policy profiles_update on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- Sem policy de INSERT nem DELETE: perfil nasce por trigger em
-- auth.users e morre em cascata com a conta.

-- =============================================================
-- households
-- =============================================================
create policy households_select on public.households for select to authenticated
using (public.is_household_member(id));

-- Qualquer usuário autenticado pode criar uma casa, desde que se
-- declare o criador. O trigger trg_household_bootstrap o insere como
-- owner logo em seguida.
create policy households_insert on public.households for insert to authenticated
with check (created_by = auth.uid());

create policy households_update on public.households for update to authenticated
using (public.can_write_household(id)) with check (public.can_write_household(id));

create policy households_delete on public.households for delete to authenticated
using (public.is_household_owner(id));

-- =============================================================
-- household_members
-- =============================================================
create policy members_select on public.household_members for select to authenticated
using (public.is_household_member(household_id));

-- Duas portas para entrar um membro:
--   1. owner adicionando alguém (inclusive membro-fantasma);
--   2. a própria pessoa criando a casa (bootstrap: ainda não é membro,
--      mas é o created_by da household).
create policy members_insert on public.household_members for insert to authenticated
with check (
  public.is_household_owner(household_id)
  or exists (
    select 1 from public.households h
    where h.id = household_id and h.created_by = auth.uid()
  )
);

-- Owner mexe em qualquer membro. Qualquer um edita o próprio cadastro
-- (nome de exibição, cor, emoji) — mas a mudança de `role` é barrada
-- pelo trigger trg_member_role_guard logo abaixo.
create policy members_update on public.household_members for update to authenticated
using (public.is_household_owner(household_id) or user_id = auth.uid())
with check (public.is_household_owner(household_id) or user_id = auth.uid());

create policy members_delete on public.household_members for delete to authenticated
using (public.is_household_owner(household_id));

-- Sem este trigger, a policy members_update deixaria um `teen`
-- promover a si mesmo a `owner` com um PATCH. RLS avalia linha, não
-- coluna; a proteção por coluna tem que vir de trigger.
create or replace function public.guard_member_role()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if new.role is distinct from old.role
     and not public.is_household_owner(old.household_id) then
    raise exception 'apenas o dono da casa pode alterar papéis'
      using errcode = '42501';
  end if;

  if new.household_id is distinct from old.household_id then
    raise exception 'membro não muda de casa' using errcode = '42501';
  end if;

  -- Nunca deixar a casa sem dono.
  if old.role = 'owner' and (new.role <> 'owner' or new.deleted_at is not null) then
    if (select count(*) from public.household_members
        where household_id = old.household_id and role = 'owner'
          and deleted_at is null and id <> old.id) = 0 then
      raise exception 'a casa precisa de pelo menos um dono'
        using errcode = '23514';
    end if;
  end if;

  return new;
end $$;

create trigger trg_member_role_guard
  before update on public.household_members
  for each row execute function public.guard_member_role();

-- =============================================================
-- household_invites
-- =============================================================
-- Só quem já está dentro enxerga os convites. O convidado NÃO lê esta
-- tabela: ele chama redeem_invite(), que é SECURITY DEFINER.
create policy invites_select on public.household_invites for select to authenticated
using (public.is_household_member(household_id));

create policy invites_insert on public.household_invites for insert to authenticated
with check (public.is_household_owner(household_id) and created_by = auth.uid());

create policy invites_update on public.household_invites for update to authenticated
using (public.is_household_owner(household_id));

create policy invites_delete on public.household_invites for delete to authenticated
using (public.is_household_owner(household_id));

-- =============================================================
-- Tabelas de casa com regra simples
-- =============================================================
-- accounts, categories, merchants, recurrences, budgets, goals,
-- goal_contributions, settlements, receipts:
--   ler   → qualquer membro
--   criar/editar → owner e adult
--   apagar (hard delete) → só owner; o app usa soft delete de qualquer
--                          forma, isto é rede de proteção
do $$
declare t text;
begin
  foreach t in array array[
    'accounts','categories','merchants','recurrences','budgets',
    'goals','goal_contributions','settlements','receipts'
  ] loop
    execute format(
      'create policy %s_select on public.%I for select to authenticated '
      'using (public.is_household_member(household_id))', t, t);
    execute format(
      'create policy %s_insert on public.%I for insert to authenticated '
      'with check (public.can_write_household(household_id))', t, t);
    execute format(
      'create policy %s_update on public.%I for update to authenticated '
      'using (public.can_write_household(household_id)) '
      'with check (public.can_write_household(household_id))', t, t);
    execute format(
      'create policy %s_delete on public.%I for delete to authenticated '
      'using (public.is_household_owner(household_id))', t, t);
  end loop;
end $$;

-- Conta privada: só o dono e o owner da casa enxergam. Sobrepõe-se à
-- policy genérica acima como restrição adicional (RESTRICTIVE faz AND
-- com as demais, ao contrário do OR das permissivas).
create policy accounts_private_guard on public.accounts
as restrictive for select to authenticated
using (
  visibility = 'household'
  or owner_id = public.current_member_id(household_id)
  or public.is_household_owner(household_id)
);

-- =============================================================
-- transactions — a tabela com a regra mais fina
-- =============================================================
-- Três restrições combinadas:
--   1. tem que ser da sua casa;
--   2. lançamento 'private' só aparece para quem criou;
--   3. 'teen' só enxerga o que é dele.
create policy transactions_select on public.transactions for select to authenticated
using (
  public.is_household_member(household_id)
  and (visibility = 'household' or created_by = auth.uid())
  and (
    public.household_role(household_id) <> 'teen'
    or member_id = public.current_member_id(household_id)
    or created_by = auth.uid()
  )
);

-- owner e adult lançam para qualquer membro. teen lança só para si.
-- viewer não lança nada.
create policy transactions_insert on public.transactions for insert to authenticated
with check (
  created_by = auth.uid()
  and (
    public.can_write_household(household_id)
    or (
      public.household_role(household_id) = 'teen'
      and member_id = public.current_member_id(household_id)
    )
  )
);

create policy transactions_update on public.transactions for update to authenticated
using (
  public.can_write_household(household_id)
  or (public.household_role(household_id) = 'teen' and created_by = auth.uid())
)
with check (
  public.can_write_household(household_id)
  or (public.household_role(household_id) = 'teen'
      and member_id = public.current_member_id(household_id))
);

create policy transactions_delete on public.transactions for delete to authenticated
using (public.is_household_owner(household_id));

-- transaction_splits herda a permissão do lançamento pai.
create policy splits_select on public.transaction_splits for select to authenticated
using (exists (select 1 from public.transactions t where t.id = transaction_id));

create policy splits_write on public.transaction_splits for all to authenticated
using (public.can_write_household(household_id))
with check (public.can_write_household(household_id));

-- =============================================================
-- payslips — o dado mais sensível do app
-- =============================================================
-- Salário só é visto por owner e adult. teen e viewer não veem
-- holerite de ninguém, nem o próprio: um adolescente não precisa
-- saber quanto os pais ganham, e um viewer (contador, parente) muito
-- menos.
--
-- Nota de produto: cônjuges veem o holerite um do outro. Isso é
-- deliberado — é o ponto do app. Quem não quiser compartilhar
-- simplesmente não cadastra o holerite e registra só o valor líquido
-- como receita comum.
create policy payslips_select on public.payslips for select to authenticated
using (public.can_write_household(household_id));

create policy payslips_write on public.payslips for all to authenticated
using (public.can_write_household(household_id))
with check (public.can_write_household(household_id));

create policy payslip_items_select on public.payslip_items for select to authenticated
using (public.can_write_household(household_id));

create policy payslip_items_write on public.payslip_items for all to authenticated
using (public.can_write_household(household_id))
with check (public.can_write_household(household_id));

-- =============================================================
-- devices — do usuário
-- =============================================================
create policy devices_all on public.devices for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- =============================================================
-- category_templates — catálogo global, só leitura
-- =============================================================
create policy templates_select on public.category_templates
for select to authenticated using (true);

-- =============================================================
-- Views: revogar do anon
-- =============================================================
do $$
declare v text;
begin
  foreach v in array array[
    'v_account_balances','v_member_month','v_category_month',
    'v_budget_progress','v_credit_card_bill','v_upcoming_bills',
    'v_household_net_worth','v_split_integrity','v_member_shared_contribution'
  ] loop
    execute format('revoke all on public.%I from anon', v);
    execute format('grant select on public.%I to authenticated', v);
  end loop;
end $$;
