# E03 — Supabase

Referências: [03-supabase-setup.md](../03-supabase-setup.md), [04-schema-sql.md](../04-schema-sql.md), [05-rls-seguranca.md](../05-rls-seguranca.md), [sql/](../sql/)

**Esta etapa tem um portão de segurança. Não passe dele sem os testes de RLS verdes.** A chave do Supabase estará dentro do APK e é pública por design; a única coisa que protege os dados financeiros da família é o que for configurado aqui.

## Tarefas

### 1. Ligar o repositório

```bash
cd ~/Neurelix/Finança
supabase init
supabase login
supabase link --project-ref skkequjojwmivdmaqczb
```

O `link` pede a senha do banco. Se estiver perdida: Dashboard › Settings › Database › Reset database password. Guarde num gerenciador de senhas, **fora do repositório**.

### 2. Copiar as migrations

```bash
mkdir -p supabase/migrations
i=0
for f in docs/sql/0*.sql; do
  i=$((i+1))
  ts=$(printf "202608041200%02d" "$i")
  cp "$f" "supabase/migrations/${ts}_$(basename "${f%.sql}" | cut -d_ -f2-).sql"
done
ls supabase/migrations   # esperado: 9 arquivos, em ordem
```

### 3. Validar localmente

**Primeiro o teste rápido**, que roda em segundos num Postgres descartável e já está pronto em [../sql/testes/](../sql/testes/):

```bash
docker run -d --name financa-pgtest \
  -e POSTGRES_PASSWORD=test -p 55432:5432 postgres:17
export PGPASSWORD=test
psql -h localhost -p 55432 -U postgres -q -v ON_ERROR_STOP=1 \
  -f docs/sql/testes/00_stub_supabase.sql
for f in docs/sql/0*.sql; do
  psql -h localhost -p 55432 -U postgres -q -v ON_ERROR_STOP=1 -f "$f" \
    || echo "FALHOU $f"
done
psql -h localhost -p 55432 -U postgres -q -f docs/sql/testes/01_funcional.sql
psql -h localhost -p 55432 -U postgres -q -f docs/sql/testes/02_rls.sql
docker rm -f financa-pgtest
```

Toda linha `obtido` tem que bater com `esperado`. Nos blocos marcados `(DEVE FALHAR)`, o resultado correto é um `ERROR:` — é a proteção funcionando.

**Depois, a stack completa**, se houver Docker:

```bash
supabase start
supabase db reset     # aplica tudo do zero, na ordem
```

`db reset` é o teste real das migrations. Falha aqui é barata; falha no remoto exige desfazer à mão.

### 4. Aplicar no remoto

```bash
supabase db push
```

Sem Docker, cole cada arquivo no SQL Editor do Dashboard, **na ordem numérica**.

### 5. Conferir os advisors

Dashboard › Advisors › Security. **Tem que estar vazio.** A tabela de correspondência entre aviso e correção está em [03-supabase-setup.md](../03-supabase-setup.md#verificar-a-rls).

### 6. Verificação estrutural

No SQL Editor — as duas queries têm que voltar vazias:

```sql
-- nenhuma tabela pública sem RLS
select tablename from pg_tables
where schemaname = 'public' and rowsecurity = false;

-- nenhuma view sem security_invoker
select viewname from pg_views v
where schemaname = 'public'
  and not exists (
    select 1 from pg_class c
    where c.relname = v.viewname
      and c.reloptions::text like '%security_invoker=on%'
  );
```

### 7. Auth

Dashboard › Authentication:

- Providers › Email ligado. Em dev, "Confirm email" desligado. **Anote em [../anexos/BLOQUEIOS.md](../anexos/BLOQUEIOS.md) que precisa ser religado antes de qualquer usuário real.**
- Minimum password length: 8
- Leaked password protection: ligado
- URL Configuration › Redirect URLs: `br.com.neurelix.financa://login-callback` e `financa://login-callback`

### 8. Criar usuários de teste

Dashboard › Authentication › Add user. Crie três: `teste-a@exemplo.com`, `teste-b@exemplo.com`, `teste-teen@exemplo.com`.

Confira que o trigger funcionou — cada um deve ter ganhado perfil, casa pessoal e categorias:

```sql
select p.display_name, h.name, count(c.id) as categorias
from profiles p
join households h on h.created_by = p.id
left join categories c on c.household_id = h.id
group by 1, 2;
-- esperado: ~70 categorias por casa
```

### 9. PORTÃO — testes de RLS

Rode todos os blocos de [05-rls-seguranca.md](../05-rls-seguranca.md#testes-de-rls). Resumo do que é bloqueante:

```sql
-- usuário sem casa nenhuma
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000"}';
select count(*) from transactions;        -- 0
select count(*) from accounts;            -- 0
select count(*) from payslips;            -- 0
select count(*) from household_members;   -- 0
reset role;
```

Qualquer valor diferente de zero é vazamento de dados entre famílias. Pare e conserte antes de escrever qualquer código Flutter.

Teste também, com o usuário `teste-a`: que ele não vê nada da casa do `teste-b`; que um `teen` lê zero holerites; que o `teen` recebe erro ao tentar mudar o próprio `role`; e que remover o último `owner` da casa é rejeitado.

### 10. Conferir os buckets

Dashboard › Storage: `receipts` (privado) e `avatars` (público). Ambos com as políticas de `0009_storage.sql`.

### 11. Cron de limpeza (opcional)

Dashboard › Database › Cron:

```
0 4 * * 0    select public.purge_deleted();
```

Remove fisicamente o que está soft-deleted há mais de 90 dias, quando todo dispositivo já convergiu.

## DoD

- [ ] `supabase db push` concluído sem erro
- [ ] Advisors › Security vazio
- [ ] As duas queries de verificação estrutural voltam vazias
- [ ] 3 usuários de teste criados, cada um com casa e ~70 categorias
- [ ] **Usuário sem casa lê 0 linhas em todas as tabelas**
- [ ] **Usuário A não lê nada da casa de B**
- [ ] **`teen` lê 0 holerites**
- [ ] **`teen` não consegue alterar o próprio `role`**
- [ ] Remover o último `owner` é rejeitado
- [ ] Buckets `receipts` e `avatars` criados com política
- [ ] `git grep -i service_role` sem resultado
- [ ] Registrado em BLOQUEIOS.md que "Confirm email" precisa ser religado

Commit: `feat(e03): schema, rls e storage no supabase`
