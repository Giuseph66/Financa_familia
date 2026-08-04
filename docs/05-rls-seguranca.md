# 05 — RLS e Segurança

## O modelo de ameaça

A chave pública do Supabase está dentro do APK. Extraí-la é trivial:

```bash
unzip -p app-release.apk | strings | grep -o 'sb_publishable_[A-Za-z0-9_-]*'
```

Com ela, qualquer pessoa faz requisições à API REST do projeto. **Nada do lado do cliente protege dado nenhum** — validação em Dart, tela escondida, botão desabilitado: tudo isso é conveniência de interface, e some quando o atacante fala direto com a API.

O que protege é exclusivamente a RLS. É por isso que o teste de RLS é bloqueante na Etapa 03 e não uma tarefa de polimento no fim.

Ameaças concretas consideradas:

| Ameaça | Defesa |
|---|---|
| Ler os dados de outra família | Toda política filtra por `is_household_member(household_id)` |
| Adolescente vendo o salário dos pais | `payslips` restrito a `owner`/`adult` |
| Adolescente se promovendo a `owner` via PATCH | Trigger `guard_member_role` — RLS avalia linha, não coluna |
| Lançar despesa em conta de outra casa | FK composta `(account_id, household_id)` |
| Baixar recibo de outra família pelo Storage | Política sobre `(storage.foldername(name))[1]` |
| Um `viewer` escrevendo qualquer coisa | `can_write_household()` exclui `viewer` |
| Casa ficar sem dono e virar órfã | Trigger `guard_member_role` |
| Escalonamento via `search_path` em `SECURITY DEFINER` | `set search_path = public, pg_temp` em todas |
| Alguém escrever `updated_at` no futuro e vencer todo conflito | Trigger `touch_row()` sobrescreve com `now()` do servidor |

## A armadilha da recursão

Esta é a coisa que mais trava gente em RLS no Supabase, então vale explicar bem.

A política de `household_members` precisa responder "esta pessoa é membro desta casa?". A resposta está em `household_members`. Escrito de forma ingênua:

```sql
-- ISTO NÃO FUNCIONA
create policy members_select on household_members for select
using (
  household_id in (select household_id from household_members where user_id = auth.uid())
);
```

O Postgres avalia a política, encontra o `SELECT` em `household_members`, e para avaliar esse `SELECT` precisa aplicar a política de `household_members` — que contém outro `SELECT` na mesma tabela. O erro é:

```
ERROR: infinite recursion detected in policy for relation "household_members"
```

A saída é `SECURITY DEFINER`. A função roda com os privilégios do dono, que **não está sujeito à RLS**, então a consulta interna não reativa a política e o ciclo se rompe:

```sql
create or replace function public.is_household_member(h uuid)
returns boolean
language sql stable
security definer                      -- ← quebra o ciclo
set search_path = public, pg_temp     -- ← obrigatório, ver abaixo
as $$
  select exists (
    select 1 from public.household_members
    where household_id = h and user_id = auth.uid() and deleted_at is null
  );
$$;
```

**Regra do projeto: nenhuma política escreve subquery direta em `household_members`.** Tudo passa por `is_household_member`, `can_write_household`, `is_household_owner`, `household_role` ou `current_member_id`.

### Por que o `search_path` é obrigatório

`SECURITY DEFINER` sem `search_path` fixo é um vetor de escalonamento de privilégio conhecido. Se um atacante conseguir criar um schema que apareça antes de `public` na busca de nomes, ele planta uma tabela `household_members` própria; a função — rodando como owner — resolve o nome para a tabela falsa e devolve `true` para qualquer coisa.

`set search_path = public, pg_temp` congela a resolução. `pg_temp` vai por último de propósito: se ficasse antes, objetos temporários da sessão do atacante teriam prioridade, que é exatamente o ataque que se quer evitar.

## Restritiva vs permissiva

Políticas do Postgres se combinam de dois jeitos, e confundir isso gera buraco:

- **`PERMISSIVE`** (padrão): várias políticas para a mesma operação se combinam com **OR**. Basta uma passar.
- **`RESTRICTIVE`**: combina com **AND**. Tem que passar em todas.

Usamos restritiva num caso, o de conta privada:

```sql
create policy accounts_private_guard on public.accounts
as restrictive for select to authenticated
using (
  visibility = 'household'
  or owner_id = public.current_member_id(household_id)
  or public.is_household_owner(household_id)
);
```

A política genérica já libera leitura para qualquer membro. Se esta fosse permissiva, seria OR com a outra e não restringiria nada. Sendo restritiva, vira AND: membro da casa **e** (a conta é compartilhada **ou** é sua).

## Testes de RLS

Não é opcional. Rode no SQL Editor depois de cada mudança em `0006_rls.sql`.

### Isolamento entre casas

```sql
-- Cria duas casas com dois usuários — use IDs reais de auth.users
-- criados via Dashboard › Authentication › Add user

set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid-do-usuario-A>"}';
select count(*) from transactions;   -- só as da casa do A
select count(*) from households;     -- 1

set local request.jwt.claims = '{"sub":"<uuid-do-usuario-B>"}';
select count(*) from transactions;   -- só as da casa do B, nenhuma do A
reset role;
```

### Usuário sem casa nenhuma

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000"}';
select count(*) from transactions;        -- 0
select count(*) from accounts;            -- 0
select count(*) from payslips;            -- 0
select count(*) from household_members;   -- 0
reset role;
```

**Qualquer resultado diferente de zero é vazamento.** Pare e conserte.

### Adolescente

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid-do-teen>"}';

select count(*) from payslips;    -- 0, sempre
select count(*) from transactions;-- só as dele

-- tentativa de se promover: TEM que dar erro
update household_members set role = 'owner' where user_id = auth.uid();
--> ERROR: apenas o dono da casa pode alterar papéis

-- tentativa de lançar no nome de outro membro: TEM que dar erro
insert into transactions (id, household_id, account_id, member_id, created_by,
                          kind, amount_cents, occurred_at)
values (gen_random_uuid(), '<casa>', '<conta>', '<outro-membro>', auth.uid(),
        'expense', 1000, now());
--> ERROR: new row violates row-level security policy
reset role;
```

### Storage

```sql
-- pela API, autenticado como membro da casa A:
--   GET /storage/v1/object/receipts/<casa-B>/<arquivo>.jpg
-- esperado: 400 ou 404, nunca o binário
```

## Segurança no dispositivo

A RLS protege o servidor. O celular tem os mesmos dados em SQLite, sem criptografia por padrão.

**Sessão em armazenamento seguro.** `SecureLocalStorage` no `Supabase.initialize` — Keychain no iOS, EncryptedSharedPreferences no Android. Nunca `SharedPreferences` puro para token.

**Bloqueio por biometria.** Opcional, ligado por padrão. `local_auth` exigindo autenticação ao abrir o app e ao voltar do background depois de 60 segundos. Sem isso, quem pegar o celular desbloqueado vê todo o histórico financeiro da família.

**Criptografia do SQLite.** Fica de fora do MVP. `sqlcipher_flutter_libs` existe e funciona, mas a chave precisaria viver no Keychain e o ganho real é pequeno: em Android e iOS modernos o diretório do app já é isolado por sandbox e cifrado em repouso pelo sistema quando há bloqueio de tela. Vale reavaliar se o app um dia sair do círculo familiar.

**Sem log de dado financeiro.** `avoid_print` está ligado no lint. O logger de produção nunca imprime `amount_cents`, `display_name` ou conteúdo de OCR. Em `--release`, o logger é no-op.

**Sem screenshot na tela de valores** (opcional, em Ajustes): `FLAG_SECURE` no Android, `isSecureTextEntry` no iOS. Também esconde o conteúdo do app no seletor de tarefas recentes.

## Checklist antes de considerar seguro

- [ ] Advisors › Security sem nenhum alerta
- [ ] As duas queries de verificação de `04-schema-sql.md` voltam vazias
- [ ] Usuário sem casa lê zero linhas de todas as tabelas
- [ ] Usuário A não enxerga nada da casa do usuário B
- [ ] `teen` lê zero holerites
- [ ] `teen` não consegue mudar o próprio `role`
- [ ] `viewer` recebe erro ao tentar inserir lançamento
- [ ] Objeto do Storage de outra casa devolve erro, não binário
- [ ] Remover o último `owner` da casa é rejeitado
- [ ] "Confirm email" religado antes do primeiro usuário real
- [ ] `service_role` key não aparece em nenhum arquivo do repositório: `git grep -i "service_role"` sem resultado
- [ ] `.env*` no `.gitignore` e nunca commitado: `git log --all --full-history -- .env` sem resultado
