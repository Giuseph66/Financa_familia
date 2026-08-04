-- =============================================================
-- 0007 — Funções chamadas pelo app (RPC) e automações
-- =============================================================

-- -------------------------------------------------------------
-- pick_member_color — cor não repetida para o novo membro
-- -------------------------------------------------------------
-- Cores diferentes por pessoa são o que torna o gráfico comparativo
-- legível. Repetir cor entre marido e esposa arruína a tela principal.
create or replace function public.pick_member_color(h uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select c from unnest(array[
       '#6750A4','#2E7D32','#C62828','#1565C0','#EF6C00',
       '#00838F','#AD1457','#4E342E','#37474F','#7B1FA2'
     ]) as c
     where c not in (
       select color from public.household_members
       where household_id = h and deleted_at is null
     )
     limit 1),
    '#6750A4'
  );
$$;

-- -------------------------------------------------------------
-- handle_new_user — cadastro cria perfil + casa pessoal
-- -------------------------------------------------------------
-- O usuário nunca vê uma tela vazia no primeiro acesso: ele já entra
-- com uma casa própria, categorias carregadas e uma conta "Carteira".
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name      text;
  v_household uuid := gen_random_uuid();
  v_member    uuid := gen_random_uuid();
begin
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    initcap(split_part(new.email, '@', 1))
  );

  insert into public.profiles (id, display_name)
  values (new.id, v_name);

  insert into public.households (id, name, created_by)
  values (v_household, 'Minhas finanças', new.id);

  insert into public.household_members
    (id, household_id, user_id, role, display_name, color)
  values
    (v_member, v_household, new.id, 'owner', v_name, '#6750A4');

  update public.profiles set default_household_id = v_household where id = new.id;

  return new;
end $$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -------------------------------------------------------------
-- seed_household — categorias e conta inicial
-- -------------------------------------------------------------
-- Copia o catálogo de category_templates para a casa. Copiar em vez
-- de compartilhar globalmente permite que cada família renomeie
-- "Alimentação" para "Rango" sem afetar ninguém, e evita um caso
-- especial no pull do sync para linhas sem household_id.
create or replace function public.seed_household()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_parent_map jsonb := '{}'::jsonb;
  r            record;
  v_id         uuid;
begin
  -- Primeiro os pais, para que os filhos tenham em quem se apoiar.
  for r in
    select * from public.category_templates
    where parent_key is null order by sort_order
  loop
    v_id := gen_random_uuid();
    insert into public.categories
      (id, household_id, template_key, name, kind, icon, color, is_system, sort_order)
    values
      (v_id, new.id, r.key, r.name, r.kind, r.icon, r.color, true, r.sort_order);
    v_parent_map := v_parent_map || jsonb_build_object(r.key, v_id);
  end loop;

  for r in
    select * from public.category_templates
    where parent_key is not null order by sort_order
  loop
    insert into public.categories
      (id, household_id, parent_id, template_key, name, kind, icon, color,
       is_system, sort_order)
    values
      (gen_random_uuid(), new.id,
       (v_parent_map ->> r.parent_key)::uuid,
       r.key, r.name, r.kind, r.icon, r.color, true, r.sort_order);
  end loop;

  insert into public.accounts
    (id, household_id, name, type, icon, color, sort_order)
  values
    (gen_random_uuid(), new.id, 'Carteira', 'cash', 'wallet', '#2E7D32', 0);

  return new;
end $$;

create trigger trg_household_bootstrap
  after insert on public.households
  for each row execute function public.seed_household();

-- -------------------------------------------------------------
-- create_invite — gera código legível
-- -------------------------------------------------------------
create or replace function public.create_invite(
  p_household uuid,
  p_role      text default 'adult',
  p_days      int  default 7
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Alfabeto sem I, O, 0 e 1: o código é lido em voz alta ou digitado
  -- a partir de um print, e essas quatro se confundem.
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code     text;
  v_try      int := 0;
begin
  if not public.is_household_owner(p_household) then
    raise exception 'apenas o dono da casa pode convidar' using errcode = '42501';
  end if;
  if p_role not in ('adult','teen','viewer') then
    raise exception 'papel inválido: %', p_role using errcode = '22023';
  end if;

  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.household_invites where code = v_code);
    v_try := v_try + 1;
    if v_try > 20 then
      raise exception 'não foi possível gerar código único';
    end if;
  end loop;

  insert into public.household_invites
    (id, household_id, code, role, created_by, expires_at)
  values
    (gen_random_uuid(), p_household, v_code, p_role, auth.uid(),
     now() + make_interval(days => p_days));

  return v_code;
end $$;

-- -------------------------------------------------------------
-- redeem_invite — aceitar convite
-- -------------------------------------------------------------
-- SECURITY DEFINER é obrigatório: o convidado precisa ler um convite
-- de uma casa da qual ainda não faz parte, e a RLS proíbe isso. A
-- função valida tudo antes de inserir, então o privilégio elevado é
-- exercido num caminho estreito e verificado.
create or replace function public.redeem_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inv  record;
  v_uid  uuid := auth.uid();
  v_name text;
begin
  if v_uid is null then
    raise exception 'não autenticado' using errcode = '42501';
  end if;

  -- ORDEM IMPORTA. A busca NÃO filtra por `uses < max_uses` aqui, e a
  -- checagem de "já é membro" vem ANTES da de esgotamento.
  --
  -- Invertido, um toque duplo no botão de aceitar — ou um retry depois
  -- de timeout de rede — falharia com "convite já utilizado" para
  -- alguém que acabou de entrar e JÁ É membro. Erro confuso num
  -- caminho que acontece o tempo todo em celular com rede ruim.
  select * into v_inv
  from public.household_invites
  where upper(code) = upper(trim(p_code))
    and revoked_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'convite inválido ou expirado' using errcode = '22023';
  end if;

  -- Idempotente: já é membro, devolve a casa sem consumir outro uso.
  if exists (
    select 1 from public.household_members
    where household_id = v_inv.household_id and user_id = v_uid and deleted_at is null
  ) then
    return v_inv.household_id;
  end if;

  if v_inv.uses >= v_inv.max_uses then
    raise exception 'convite já utilizado' using errcode = '22023';
  end if;

  select display_name into v_name from public.profiles where id = v_uid;

  insert into public.household_members
    (id, household_id, user_id, role, display_name, color)
  values
    (gen_random_uuid(), v_inv.household_id, v_uid, v_inv.role,
     coalesce(v_name, 'Membro'), public.pick_member_color(v_inv.household_id));

  update public.household_invites set uses = uses + 1 where id = v_inv.id;

  return v_inv.household_id;
end $$;

-- -------------------------------------------------------------
-- sync_pull — puxa tudo que mudou, numa chamada só
-- -------------------------------------------------------------
-- Sem isto seriam 15 requisições HTTP por sincronização. Com isto, uma.
--
-- SECURITY INVOKER (o padrão) é essencial aqui: a RLS de quem chama
-- é aplicada dentro da função, então um 'teen' recebe automaticamente
-- só o subconjunto que pode ver, sem nenhuma lógica extra.
--
-- Sobre o cursor: quando alguma tabela bate o limite, devolvemos o
-- maior updated_at já entregue em vez do horário do servidor —
-- avançar até "agora" pularia as linhas que ficaram de fora. O cliente
-- ainda aplica uma sobreposição de 2 segundos por cima disso. Reler
-- linha repetida é inofensivo porque todo apply é upsert por id.
create or replace function public.sync_pull(
  p_household uuid,
  p_since     timestamptz default '-infinity'::timestamptz,
  p_limit     int default 1000
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_tables text[] := array[
    'household_members','accounts','categories','merchants','recurrences',
    'receipts','transactions','transaction_splits','budgets','goals',
    'goal_contributions','payslips','payslip_items','settlements'
  ];
  t            text;
  v_rows       jsonb;
  v_out        jsonb := '{}'::jsonb;
  v_count      int;
  v_has_more   boolean := false;
  v_max_seen   timestamptz := p_since;
  v_now        timestamptz := now();
begin
  if not public.is_household_member(p_household) then
    raise exception 'sem acesso à casa %', p_household using errcode = '42501';
  end if;

  -- households tem `id`, não `household_id`; vai fora do laço.
  select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb) into v_rows
  from (
    select * from public.households
    where id = p_household and updated_at > p_since
  ) h;
  v_out := v_out || jsonb_build_object('households', v_rows);

  foreach t in array v_tables loop
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb), count(*) '
      'from (select * from public.%I '
      '      where household_id = $1 and updated_at > $2 '
      '      order by updated_at, sync_version limit $3) x', t)
    into v_rows, v_count
    using p_household, p_since, p_limit;

    v_out := v_out || jsonb_build_object(t, v_rows);

    if v_count >= p_limit then
      v_has_more := true;
      -- maior updated_at efetivamente entregue nesta tabela
      v_max_seen := greatest(
        v_max_seen,
        (select max((e ->> 'updated_at')::timestamptz)
         from jsonb_array_elements(v_rows) e)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'server_time', v_now,
    'cursor',      case when v_has_more then v_max_seen else v_now end,
    'has_more',    v_has_more,
    'data',        v_out
  );
end $$;

-- -------------------------------------------------------------
-- create_transfer — duas pernas, atômicas
-- -------------------------------------------------------------
-- Fazer isso em duas chamadas do cliente permitiria um estado em que
-- saiu de uma conta e não entrou na outra. Aqui é uma transação só.
create or replace function public.create_transfer(
  p_household   uuid,
  p_from        uuid,
  p_to          uuid,
  p_amount      bigint,
  p_occurred_at timestamptz,
  p_member      uuid default null,
  p_description text default null,
  p_out_id      uuid default null,
  p_in_id       uuid default null
)
returns uuid
language plpgsql
as $$
declare
  v_group uuid := gen_random_uuid();
begin
  if p_from = p_to then
    raise exception 'origem e destino são a mesma conta' using errcode = '22023';
  end if;
  if p_amount <= 0 then
    raise exception 'valor deve ser positivo' using errcode = '22023';
  end if;

  insert into public.transactions
    (id, household_id, account_id, member_id, created_by, kind, amount_cents,
     occurred_at, description, transfer_group_id, source)
  values
    (coalesce(p_out_id, gen_random_uuid()), p_household, p_from, p_member,
     auth.uid(), 'transfer_out', p_amount, p_occurred_at, p_description,
     v_group, 'manual'),
    (coalesce(p_in_id, gen_random_uuid()), p_household, p_to, p_member,
     auth.uid(), 'transfer_in', p_amount, p_occurred_at, p_description,
     v_group, 'manual');

  return v_group;
end $$;

-- -------------------------------------------------------------
-- advance_recurrence — calcula o próximo vencimento
-- -------------------------------------------------------------
-- Regra que costuma dar errado: dia 31 em mês de 30 dias cai no
-- último dia do mês, não transborda para o dia 1 do mês seguinte.
create or replace function public.next_due_date(
  p_from      date,
  p_frequency text,
  p_interval  int,
  p_day       smallint
)
returns date
language plpgsql
immutable
as $$
declare
  v_step  interval;
  v_base  date;
  v_last  int;
begin
  v_step := case p_frequency
    when 'weekly'     then make_interval(weeks  => p_interval)
    when 'biweekly'   then make_interval(weeks  => 2 * p_interval)
    when 'monthly'    then make_interval(months => p_interval)
    when 'bimonthly'  then make_interval(months => 2 * p_interval)
    when 'quarterly'  then make_interval(months => 3 * p_interval)
    when 'semiannual' then make_interval(months => 6 * p_interval)
    when 'yearly'     then make_interval(years  => p_interval)
  end;

  v_base := (p_from + v_step)::date;

  -- Frequências mensais respeitam o dia escolhido, limitado ao último
  -- dia do mês de destino.
  if p_day is not null
     and p_frequency in ('monthly','bimonthly','quarterly','semiannual','yearly') then
    v_last := extract(day from (date_trunc('month', v_base)
                                + interval '1 month - 1 day'))::int;
    v_base := date_trunc('month', v_base)::date + (least(p_day, v_last) - 1);
  end if;

  return v_base;
end $$;

-- -------------------------------------------------------------
-- purge_deleted — limpeza física do que já convergiu
-- -------------------------------------------------------------
-- Soft delete é obrigatório para o sync propagar exclusões, mas linha
-- morta acumula para sempre. Depois de 90 dias, todo dispositivo já
-- recebeu o delete e a linha pode sair de verdade.
-- Agende em Database › Cron: 0 4 * * 0  →  select public.purge_deleted();
create or replace function public.purge_deleted(p_older_than interval default '90 days')
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t text; v_total int := 0; v_n int;
begin
  foreach t in array array[
    'transaction_splits','transactions','goal_contributions','goals',
    'budgets','payslip_items','payslips','settlements','receipts',
    'recurrences','merchants','categories','accounts','household_members'
  ] loop
    execute format(
      'delete from public.%I where deleted_at is not null and deleted_at < now() - $1', t)
    using p_older_than;
    get diagnostics v_n = row_count;
    v_total := v_total + v_n;
  end loop;
  return v_total;
end $$;

revoke all on function public.purge_deleted(interval) from public, anon, authenticated;

grant execute on function
  public.create_invite(uuid, text, int),
  public.redeem_invite(text),
  public.sync_pull(uuid, timestamptz, int),
  public.create_transfer(uuid, uuid, uuid, bigint, timestamptz, uuid, text, uuid, uuid),
  public.next_due_date(date, text, int, smallint),
  public.pick_member_color(uuid)
to authenticated;
