# Testes do Schema

Scripts que validam as migrations num Postgres descartável, **sem tocar no projeto Supabase**. Rodam em poucos segundos e pegam a maior parte dos erros antes do `db push`.

Estes três scripts já foram executados e passam contra `docs/sql/` em 2026-08-04. Foi rodando eles que apareceram três bugs que estavam no SQL original:

- `v_credit_card_bill` agrupava por posição (`group by ..., 2`), que aponta para a coluna errada
- `redeem_invite` verificava o esgotamento do convite antes da idempotência, fazendo um toque duplo em "aceitar" dar erro para quem já era membro
- faltava `grant usage on sequence sync_version_seq to authenticated`, o que quebraria **toda** inserção vinda do aplicativo

## Como rodar

```bash
docker run -d --name financa-pgtest \
  -e POSTGRES_PASSWORD=test -p 55432:5432 postgres:17

export PGPASSWORD=test
PSQL="psql -h localhost -p 55432 -U postgres -q"

# 1. stub do que o Supabase fornece de fábrica
$PSQL -v ON_ERROR_STOP=1 -f docs/sql/testes/00_stub_supabase.sql

# 2. as migrations, na ordem
for f in docs/sql/0*.sql; do
  $PSQL -v ON_ERROR_STOP=1 -f "$f" || echo "FALHOU $f"
done

# 3. teste funcional — toda linha "obtido" tem que bater com "esperado"
$PSQL -f docs/sql/testes/01_funcional.sql

# 4. teste de RLS
$PSQL -f docs/sql/testes/02_rls.sql

docker rm -f financa-pgtest
```

Para rodar de novo do zero:

```bash
$PSQL -c "drop schema if exists public cascade;
          drop schema if exists auth cascade;
          drop schema if exists storage cascade;
          create schema public;"
```

## Os arquivos

**`00_stub_supabase.sql`** — recria o mínimo do Supabase num Postgres puro: `auth.users`, `auth.uid()`, `storage.buckets`, `storage.objects`, `storage.foldername()` e os papéis `anon`/`authenticated`/`service_role`. **Não é migration** e nunca vai para `supabase/migrations/`.

**`01_funcional.sql`** — cadastro dispara o bootstrap, convite e idempotência, saldos, `signed_amount_cents`, transferência atômica, comparativo entre membros, totais de holerite por trigger, `sync_pull`, e os casos de borda de `next_due_date`.

**`02_rls.sql`** — isolamento entre casas, usuário sem casa lendo zero, restrições do `teen`, guarda de papel, último dono, visibilidade privada, e isolamento do Storage.

## Como ler o resultado

Cada consulta devolve `teste | obtido | esperado`. **Toda linha tem que bater.**

Nos blocos marcados `(DEVE FALHAR)` do `02_rls.sql`, o resultado correto é um `ERROR:` — é a proteção funcionando. Se um desses blocos passar sem erro, há um buraco de segurança.

## O que estes testes NÃO cobrem

- Comportamento real do Supabase Auth (confirmação de e-mail, JWT, refresh)
- Políticas de Storage no caminho HTTP real, com a API
- Desempenho sob volume
- Migrations incrementais (só a aplicação do zero)

Para isso, use `supabase start` + `supabase db reset` com Docker, que roda a stack inteira. Estes scripts são o teste rápido de dentro do laço.
