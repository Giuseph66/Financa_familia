# 04 — Guia das Migrations

O SQL completo está em [sql/](sql/). Este documento explica o que cada arquivo faz, a ordem obrigatória e as regras para evoluir o schema depois.

## Os arquivos, na ordem

| # | Arquivo | Cria |
|---|---|---|
| 0001 | `foundation.sql` | Extensão `pgcrypto`, sequência `sync_version_seq`, `touch_row()`, `try_uuid()`, `normalize_name()`, `attach_sync_triggers()` |
| 0002 | `identity.sql` | `profiles`, `households`, `household_members`, `household_invites` + as **funções de autorização** |
| 0003 | `core.sql` | `accounts`, `category_templates`, `categories`, `merchants`, `recurrences`, `receipts`, `transactions`, `transaction_splits` |
| 0004 | `planning_income.sql` | `budgets`, `goals`, `goal_contributions`, `payslips`, `payslip_items`, `settlements`, `devices` |
| 0005 | `views.sql` | As 9 views de relatório |
| 0006 | `rls.sql` | Liga RLS e cria todas as políticas |
| 0007 | `rpc.sql` | `handle_new_user`, `seed_household`, `create_invite`, `redeem_invite`, `sync_pull`, `create_transfer`, `next_due_date`, `purge_deleted` |
| 0008 | `seed_categories.sql` | Catálogo de ~70 categorias brasileiras |
| 0009 | `storage.sql` | Buckets `receipts` e `avatars` + políticas |

A ordem importa por dependência real: 0003 referencia funções de 0001, 0005 lê tabelas de 0003 e 0004, 0006 usa as funções de autorização de 0002, e 0007 popula a partir de 0008.

Uma sutileza de 0003: `recurrences` e `receipts` são declaradas ali, antes de `transactions`, apesar de conceitualmente pertencerem a outros grupos. É porque `transactions` tem chave estrangeira para as duas, e o Postgres exige que a tabela referenciada exista primeiro.

## Detalhes que não são óbvios olhando o SQL

**`attach_sync_triggers(array[...])` no fim de cada migration.** Aplica `touch_row()` em lote. Sem isso, `updated_at` nunca é atualizado e o pull do sync simplesmente não vê a linha mudar — bug silencioso, difícil de rastrear, e a razão de existir o helper em vez de 20 `CREATE TRIGGER` copiados à mão.

**FK composta `transactions → accounts (id, household_id)`.** Impede lançar numa conta de outra casa. Exige `UNIQUE (id, household_id)` em `accounts`, que parece redundante já que `id` é PK — mas o Postgres precisa desse índice único para aceitar a FK composta. Não remova achando que é sobra.

**Nada de `format('%1$s')` dentro de bloco `$$`.** A sequência `$s` faz o parser de dollar-quoting procurar um fechamento e o resultado é imprevisível. Use `%s`/`%I` posicionais simples, repetindo o argumento: `format('... %s ... %I', t, t)`.

**`security_invoker = on` em toda view.** Sem isso a view roda com os privilégios de quem a criou e ignora a RLS de quem consulta. As tabelas ficam blindadas e a view vaza tudo entre casas. É a falha de segurança clássica de Supabase.

**`enable row level security`, e deliberadamente *não* `force`.** `FORCE` sujeitaria o dono da tabela às políticas, o que quebraria todas as funções `SECURITY DEFINER` do projeto — inclusive `is_household_member()` (voltaria a recursão) e `handle_new_user()` (o cadastro de usuário falharia, porque `profiles` não tem política de INSERT). O comentário no topo de `0006_rls.sql` detalha.

O risco que `FORCE` cobriria — testar como dono e concluir erradamente que a política funciona — é resolvido pelo procedimento de teste: todo teste de RLS usa `set local role authenticated` com um JWT simulado, e portanto exercita as políticas de verdade.

## Regras para evoluir o schema

**Migration aplicada é imutável.** Depois de `supabase db push`, aquele arquivo nunca mais é editado. A CLI guarda um hash; alterá-lo dessincroniza o histórico e o próximo push falha. Precisa mudar? Nova migration.

**Coluna nova entra anulável ou com default.** `ALTER TABLE ... ADD COLUMN x text NOT NULL` sem default trava a tabela e falha se já houver linha. O caminho é: adicionar anulável → preencher → só então aplicar `NOT NULL`, se realmente precisar.

**Alterar CHECK de enum é operação de dois passos:**

```sql
alter table transactions drop constraint transactions_kind_check;
alter table transactions add constraint transactions_kind_check
  check (kind in ('expense','income','transfer_out','transfer_in','novo_valor'));
```

**Toda tabela sincronizável nova precisa de cinco coisas**, ou o sync a ignora em silêncio:

1. as colunas padrão (`id`, `household_id`, `created_at`, `updated_at`, `deleted_at`, `sync_version`);
2. índice `(household_id, updated_at)`;
3. chamada em `attach_sync_triggers`;
4. as quatro políticas de RLS;
5. o nome no array `v_tables` dentro de `sync_pull` — **este é o esquecido**. Sem ele, o app grava local, faz push com sucesso, e nunca recebe de volta em outro dispositivo.

Adicionar tabela também exige mexer no lado Flutter: tabela Drift correspondente, mapper, e a posição certa na ordem de push. [06](06-banco-local-drift.md) e [07](07-sync-engine.md) detalham.

## Como validar uma migration

```bash
supabase db reset     # do zero, na ordem, em banco limpo
```

Passou aqui, passa no remoto. É o único teste que importa antes do `push`.

Depois de subir, sempre:

```sql
-- nenhuma tabela pública pode ficar sem RLS
select tablename from pg_tables
where schemaname = 'public' and rowsecurity = false;

-- nenhuma view pode ficar sem security_invoker
select viewname from pg_views v
where schemaname = 'public'
  and not exists (
    select 1 from pg_class c
    where c.relname = v.viewname
      and c.reloptions::text like '%security_invoker=on%'
  );
```

As duas queries têm que voltar vazias.
