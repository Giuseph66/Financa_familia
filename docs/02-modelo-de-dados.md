# 02 — Modelo de Dados

Este documento é a fonte da verdade. O SQL em [sql/](sql/) implementa exatamente o que está aqui, e o schema Drift em [06-banco-local-drift.md](06-banco-local-drift.md) espelha o mesmo. **Divergiu, quebrou o sync.**

## Convenções aplicadas a toda tabela sincronizável

Toda tabela que participa do sync carrega este conjunto de colunas:

```sql
id            uuid        primary key,          -- gerado no CLIENTE, UUID v7
household_id  uuid        not null references households(id) on delete cascade,
created_at    timestamptz not null default now(),
updated_at    timestamptz not null default now(),   -- escrito por TRIGGER, nunca pelo cliente
deleted_at    timestamptz,                          -- soft delete
sync_version  bigint      not null default nextval('sync_version_seq')
```

Três regras que valem sempre:

**`household_id` é desnormalizado em toda tabela**, mesmo nas filhas onde daria para chegar via join (`transaction_splits`, `payslip_items`). Isso não é descuido — é o que permite escrever uma política de RLS de uma linha e filtrar o pull por casa sem join. O custo é manter a coerência na escrita; o benefício é RLS simples e rápida.

**`updated_at` é sempre do servidor.** O trigger `touch_updated_at()` sobrescreve o que o cliente mandar. Relógio de celular erra, muda com fuso, e o usuário pode ajustar na mão. Se o cliente pudesse escrever `updated_at`, um relógio adiantado venceria toda disputa de conflito para sempre.

**Enums são `text` + `CHECK`, não `ENUM` nativo.** Tipo `ENUM` no Postgres exige `ALTER TYPE` para adicionar valor, não pode ser removido dentro de transação, e o Drift não tem mapeamento natural. `text` com constraint dá a mesma garantia e evolui com um `ALTER TABLE ... DROP CONSTRAINT ... ADD CONSTRAINT`.

---

## Mapa das entidades

```
auth.users (Supabase)
    │
    └─ profiles ─────────┐
                         │
                  household_members ──── households ──── household_invites
                         │                    │
        ┌────────────────┼────────────────────┼──────────────────┐
        │                │                    │                  │
    accounts        categories            merchants         recurrences
        │                │                    │                  │
        └────────────────┴──── transactions ──┴──────────────────┘
                               │    │    │
              transaction_splits    │    receipts
                                    │
                              payslips ── payslip_items

    budgets · goals · goal_contributions · settlements · devices
```

---

## Identidade e grupo

### `profiles`

Extensão de `auth.users`. Criada por trigger no cadastro — o app nunca insere aqui diretamente.

| Coluna | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | = `auth.users.id`, `on delete cascade` |
| `display_name` | text NOT NULL | Vem do metadata do signup, ou o e-mail antes do `@` |
| `avatar_url` | text | Storage público, bucket `avatars` |
| `locale` | text NOT NULL | default `'pt_BR'` |
| `currency` | text NOT NULL | default `'BRL'` |
| `default_household_id` | uuid | Qual casa abrir ao entrar |
| `onboarded_at` | timestamptz | NULL = mostra onboarding |

Não tem `household_id` nem `deleted_at`: perfil é por usuário, não por casa, e some junto com a conta de auth.

### `households`

A "casa". Um usuário pode pertencer a várias — a pessoal e a da família, por exemplo.

| Coluna | Tipo | Notas |
|---|---|---|
| `name` | text NOT NULL | "Casa", "Meu pessoal" |
| `created_by` | uuid NOT NULL | → `auth.users` |
| `currency` | text NOT NULL | default `'BRL'` |
| `month_start_day` | smallint NOT NULL | default 1, `CHECK between 1 and 28` |

`month_start_day` existe porque muita gente pensa o mês financeiro a partir do dia do pagamento, não do dia 1. Quem recebe dia 5 quer que "este mês" vá de 5 a 4. Limitado a 28 porque 29/30/31 não existem em todo mês.

Ao criar um usuário, o trigger cria automaticamente uma household pessoal e o coloca como `owner`. O usuário nunca vê uma tela vazia.

### `household_members`

Ligação usuário ↔ casa, com papel. **É a tabela que a RLS inteira consulta**, então merece atenção.

| Coluna | Tipo | Notas |
|---|---|---|
| `household_id` | uuid NOT NULL | |
| `user_id` | uuid | → `auth.users`. **Anulável** |
| `role` | text NOT NULL | `owner` · `adult` · `teen` · `viewer` |
| `display_name` | text NOT NULL | Como aparece nos relatórios |
| `color` | text NOT NULL | Hex. Identifica a pessoa nos gráficos |
| `avatar_emoji` | text | Alternativa leve à foto |
| `income_share_pct` | numeric(5,2) | Rateio padrão das despesas comuns |
| `joined_at` | timestamptz NOT NULL | |
| `UNIQUE (household_id, user_id)` | | parcial, `where user_id is not null` |

`user_id` anulável habilita o **membro-fantasma**: um filho pequeno ou alguém sem smartphone pode existir como membro, ter gastos atribuídos, aparecer no comparativo — e ser convertido em usuário real depois, sem perder histórico. É um campo, e evita uma migração dolorosa lá na frente.

Papéis:

| Papel | Pode |
|---|---|
| `owner` | Tudo, inclusive convidar, remover membro e excluir a casa |
| `adult` | Tudo em dados; não gerencia membros nem exclui a casa |
| `teen` | CRUD só nos **próprios** lançamentos; vê apenas contas marcadas visíveis para ele; **não vê holerite de ninguém** |
| `viewer` | Só leitura (contador, ou um dos dois que só quer acompanhar) |

### `household_invites`

| Coluna | Tipo | Notas |
|---|---|---|
| `code` | text NOT NULL UNIQUE | 8 caracteres, alfabeto sem ambiguidade (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789` — sem I, O, 0, 1) |
| `role` | text NOT NULL | Papel concedido ao aceitar |
| `expires_at` | timestamptz NOT NULL | default `now() + 7 days` |
| `max_uses` / `uses` | int | default 1 / 0 |
| `revoked_at` | timestamptz | |

Aceitar é via RPC `redeem_invite(code)` com `security definer` — o convidado precisa ler o convite de uma casa da qual ainda não faz parte, o que a RLS normal proíbe. A função valida expiração, usos e revogação antes de inserir o membro.

---

## Contas e categorias

### `accounts`

| Coluna | Tipo | Notas |
|---|---|---|
| `owner_id` | uuid | → `household_members`. **NULL = conta da casa** |
| `name` | text NOT NULL | |
| `type` | text NOT NULL | ver tabela abaixo |
| `institution` | text | "Nubank", "Caixa" |
| `color` / `icon` | text | |
| `opening_balance_cents` | bigint NOT NULL | default 0 |
| `credit_limit_cents` | bigint | só cartão |
| `statement_closing_day` | smallint | dia do fechamento da fatura |
| `statement_due_day` | smallint | dia do vencimento |
| `include_in_totals` | boolean NOT NULL | default true |
| `visibility` | text NOT NULL | `household` · `private` |
| `archived_at` | timestamptz | some das listas, mantém o histórico |
| `sort_order` | int NOT NULL | |

Tipos de conta:

| Tipo | Uso |
|---|---|
| `checking` | Conta corrente |
| `savings` | Poupança |
| `cash` | Dinheiro na carteira |
| `credit_card` | Cartão — o único com fatura e ciclo |
| `benefit` | Vale-alimentação, vale-refeição |
| `investment` | Aplicações |
| `other` | |

`benefit` como tipo próprio importa no Brasil: saldo de VR não é dinheiro livre, não pode virar poupança, e misturar isso com a conta corrente distorce o saldo disponível. Fica separado e com `include_in_totals` a critério do usuário.

**Cartão de crédito** tem semântica diferente. O saldo é dívida, não patrimônio, e o que interessa é a fatura do ciclo, não o mês-calendário. A view `v_credit_card_bill` agrupa lançamentos por ciclo usando `statement_closing_day`.

### `categories`

| Coluna | Tipo | Notas |
|---|---|---|
| `parent_id` | uuid | → `categories`. Máx. 2 níveis |
| `name` | text NOT NULL | |
| `kind` | text NOT NULL | `expense` · `income` |
| `icon` | text NOT NULL | nome do ícone Material |
| `color` | text NOT NULL | hex |
| `is_system` | boolean NOT NULL | veio do catálogo; pode renomear, não pode apagar |
| `sort_order` | int NOT NULL | |
| `archived_at` | timestamptz | |

**Decisão: categorias são copiadas para cada casa, não compartilhadas globalmente.** Existe uma tabela `category_templates` (não sincronizada, só leitura) e um trigger que copia o catálogo para `categories` quando uma household nasce.

A alternativa — `household_id NULL` significando "global" — parece mais limpa mas cria dois problemas: o pull do sync precisa de um caso especial para linhas sem casa, e o usuário não pode renomear "Alimentação" para "Rango" sem afetar todo mundo. Duplicar ~40 linhas por casa é barato e elimina os dois.

Catálogo em [anexos/seed-categorias.md](anexos/seed-categorias.md).

### `merchants`

Estabelecimentos, normalizados. Alimenta autocomplete e a sugestão de categoria.

| Coluna | Tipo | Notas |
|---|---|---|
| `name` | text NOT NULL | como o usuário digitou |
| `normalized_name` | text NOT NULL | minúsculo, sem acento, sem pontuação |
| `default_category_id` | uuid | aprendido do uso |
| `default_account_id` | uuid | aprendido do uso |
| `cnpj` | text | quando vem do OCR |
| `use_count` | int NOT NULL | |
| `last_used_at` | timestamptz | |
| `UNIQUE (household_id, normalized_name)` | | |

Esta tabela é a **camada zero de inteligência do app, e não usa IA nenhuma**. Você digita "Carrefour" pela terceira vez e o app já sabe que é Mercado. Resolve a maioria dos casos por frequência pura, de graça e offline. A IA de [16-ia-futuro.md](16-ia-futuro.md) só entra onde isso não alcança.

---

## Lançamentos

### `transactions`

O centro do app.

| Coluna | Tipo | Notas |
|---|---|---|
| `account_id` | uuid NOT NULL | |
| `category_id` | uuid | NULL = "sem categoria", permitido |
| `member_id` | uuid | → `household_members`. De quem é |
| `created_by` | uuid NOT NULL | → `auth.users`. Quem digitou |
| `kind` | text NOT NULL | `expense` · `income` · `transfer_out` · `transfer_in` |
| `amount_cents` | bigint NOT NULL | `CHECK > 0` — **sempre positivo** |
| `signed_amount_cents` | bigint GENERATED | `-amount` se saída, `+amount` se entrada |
| `currency` | text NOT NULL | default `'BRL'` |
| `occurred_at` | timestamptz NOT NULL | quando aconteceu (≠ quando foi digitado) |
| `description` | text | opcional, sempre |
| `merchant_id` | uuid | |
| `payment_method` | text | `pix` · `debit` · `credit` · `cash` · `boleto` · `transfer` · `benefit_card` · `other` |
| `installment_no` | smallint | 3 de 12 |
| `installment_total` | smallint | |
| `installment_group_id` | uuid | liga as parcelas |
| `transfer_group_id` | uuid | liga as duas pernas da transferência |
| `recurrence_id` | uuid | se nasceu de conta fixa |
| `receipt_id` | uuid | foto do cupom |
| `status` | text NOT NULL | `pending` · `cleared` · `reconciled` |
| `visibility` | text NOT NULL | `household` · `private` |
| `is_reimbursable` | boolean NOT NULL | despesa a ser devolvida |
| `notes` | text | |
| `tags` | text[] NOT NULL | default `'{}'` |
| `source` | text NOT NULL | `manual` · `quick_add` · `widget` · `ocr` · `recurrence` · `import` · `ai` |

Pontos que exigem cuidado:

**Quatro `kind`, não três.** Transferência entre contas próprias não é receita nem despesa — se fosse, o total do mês contaria dinheiro que só mudou de bolso. Uma transferência grava **duas linhas** com o mesmo `transfer_group_id`: `transfer_out` na origem e `transfer_in` no destino. Relatório de despesa filtra `kind = 'expense'`, e a transferência simplesmente não aparece. Saldo de conta soma tudo, e fecha.

**Coluna gerada `signed_amount_cents`:**

```sql
signed_amount_cents bigint generated always as (
  case when kind in ('expense','transfer_out') then -amount_cents else amount_cents end
) stored
```

Isso torna qualquer soma um `SUM(signed_amount_cents)` sem `CASE` espalhado por dez queries. Sendo `stored` e gerada pelo banco, é impossível ficar dessincronizada do `kind`.

**`source` é para produto, não para debug.** Saber que 70% dos lançamentos vêm do widget e 5% do OCR é o que diz onde investir. Custa uma coluna.

**Parcelamento.** Uma compra em 12x gera 12 linhas, uma por mês, com o mesmo `installment_group_id`. Não uma linha com valor cheio. É assim que a fatura do cartão realmente funciona, e é a única forma de o mês futuro mostrar o comprometimento correto. A UI mostra "Notebook (3/12)".

### `transaction_splits`

Divide um lançamento em várias categorias ou entre vários membros.

| Coluna | Tipo | Notas |
|---|---|---|
| `transaction_id` | uuid NOT NULL | `on delete cascade` |
| `category_id` | uuid | |
| `member_id` | uuid | |
| `amount_cents` | bigint NOT NULL | `CHECK > 0` |
| `note` | text | |

Dois usos, o mesmo mecanismo. Compra de R$ 250 no mercado que tinha R$ 200 de comida e R$ 50 de produto de limpeza: dois splits com categorias diferentes. Compra de R$ 300 rateada meio a meio entre o casal: dois splits com membros diferentes.

**Invariante:** `SUM(splits.amount_cents) = transaction.amount_cents`.

**Isso não é uma constraint de banco, e é intencional.** Um trigger que valide a soma quebra o sync: o pull traz a transação e os splits em ordem indeterminada, e o trigger dispara com os splits pela metade, rejeitando dados válidos. A validação fica em duas camadas: o app garante na escrita (a UI não deixa salvar desbalanceado), e a view `v_split_integrity` lista as divergências para uma tela de diagnóstico em Ajustes. Sem splits, a transação é integralmente da categoria e do membro do cabeçalho.

---

## Renda detalhada

### `payslips` — holerite

Feito para a realidade CLT brasileira. **Totalmente opcional**: quem só quer registrar "caiu R$ 3.200" faz um lançamento de receita normal e ignora esta tela.

| Coluna | Tipo | Notas |
|---|---|---|
| `member_id` | uuid NOT NULL | de quem é o salário |
| `account_id` | uuid | onde caiu |
| `employer` | text | |
| `reference_month` | date NOT NULL | sempre dia 1 do mês de competência |
| `kind` | text NOT NULL | `monthly` · `thirteenth_1` · `thirteenth_2` · `vacation` · `termination` · `advance` |
| `gross_cents` | bigint NOT NULL | soma dos `earning` |
| `deductions_cents` | bigint NOT NULL | soma dos `deduction` |
| `net_cents` | bigint NOT NULL | `gross - deductions` |
| `paid_on` | date | |
| `transaction_id` | uuid | o lançamento do líquido |
| `receipt_id` | uuid | foto do contracheque |

`kind` separa 13º primeira e segunda parcela, férias e rescisão porque essas entradas distorcem a média mensal. O relatório de renda média exclui não-`monthly` por padrão, com um toggle.

### `payslip_items`

| Coluna | Tipo | Notas |
|---|---|---|
| `payslip_id` | uuid NOT NULL | `on delete cascade` |
| `kind` | text NOT NULL | `earning` · `deduction` · `info` |
| `code` | text | código da rubrica no holerite |
| `label` | text NOT NULL | "Adicional de insalubridade" |
| `amount_cents` | bigint NOT NULL | |
| `reference` | text | "20%", "12h", "5 dias" |
| `sort_order` | int NOT NULL | |

`kind = 'info'` é para linhas que aparecem no holerite mas não entram na conta: base do FGTS, base do INSS, salário-família informativo. Sem isso o usuário tenta somar e não bate com o papel.

Rubricas comuns pré-cadastradas em [anexos/seed-rubricas.md](anexos/seed-rubricas.md), com as de insalubridade e periculosidade em destaque porque é o caso concreto da persona.

Ao salvar um holerite, o app oferece criar o lançamento de receita do líquido, já vinculado. Uma tela, dois registros coerentes.

---

## Planejamento

### `budgets`

| Coluna | Tipo | Notas |
|---|---|---|
| `scope` | text NOT NULL | `household` · `member` |
| `member_id` | uuid | obrigatório se `scope = 'member'` |
| `category_id` | uuid | NULL = teto geral de gastos |
| `name` | text | |
| `period` | text NOT NULL | `weekly` · `monthly` · `yearly` |
| `amount_cents` | bigint NOT NULL | |
| `starts_on` | date NOT NULL | |
| `ends_on` | date | NULL = sem prazo |
| `rollover` | boolean NOT NULL | sobra passa pro mês seguinte |
| `alert_pct` | smallint NOT NULL | default 80 |

`scope` permite "a casa gasta no máximo R$ 1.200 em mercado" e "eu gasto no máximo R$ 300 em besteira" convivendo.

### `goals` e `goal_contributions`

| `goals` | Tipo | Notas |
|---|---|---|
| `name` | text NOT NULL | "Viagem", "Reserva de emergência" |
| `scope` / `member_id` | | igual budgets |
| `target_cents` | bigint NOT NULL | |
| `target_date` | date | |
| `account_id` | uuid | conta onde o dinheiro fica |
| `icon` / `color` | text | |
| `archived_at` | timestamptz | |

`goal_contributions`: `goal_id`, `amount_cents`, `occurred_at`, `transaction_id`, `note`. O progresso é `SUM(contributions)` — de novo, calculado, nunca armazenado.

### `recurrences` — contas fixas e assinaturas

| Coluna | Tipo | Notas |
|---|---|---|
| `name` | text NOT NULL | "Aluguel", "Netflix" |
| `account_id` / `category_id` / `member_id` | uuid | |
| `kind` | text NOT NULL | `expense` · `income` |
| `amount_cents` | bigint NOT NULL | |
| `amount_is_estimate` | boolean NOT NULL | conta de luz varia |
| `frequency` | text NOT NULL | `weekly` · `biweekly` · `monthly` · `bimonthly` · `quarterly` · `semiannual` · `yearly` |
| `interval_count` | int NOT NULL | default 1 — "a cada 2 meses" |
| `day_of_month` | smallint | |
| `weekday` | smallint | 0=domingo |
| `next_due_on` | date NOT NULL | |
| `ends_on` | date | |
| `auto_post` | boolean NOT NULL | default **false** |
| `remind_days_before` | smallint NOT NULL | default 2 |
| `paused_at` | timestamptz | |

`auto_post = false` por padrão, deliberadamente. Lançar automático parece conveniente e envenena os dados: a conta de luz veio R$ 40 mais cara, o app lançou o valor antigo, e o relatório vira ficção. O default é notificar e deixar o usuário confirmar com um toque, já preenchido. `auto_post` fica disponível para valor genuinamente fixo, tipo aluguel.

`day_of_month = 31` num mês de 30 dias cai no último dia. Regra implementada em `core/date/recurrence_calculator.dart` e coberta por teste — é onde esse tipo de código costuma errar.

### `settlements` — acerto entre membros

| Coluna | Tipo | Notas |
|---|---|---|
| `from_member_id` / `to_member_id` | uuid NOT NULL | |
| `amount_cents` | bigint NOT NULL | |
| `period_start` / `period_end` | date | período acertado |
| `settled_at` | timestamptz | NULL = pendente |
| `transaction_id` | uuid | o pix que quitou |
| `note` | text | |

Fecha o ciclo do comparativo: o app aponta "você bancou R$ 200 a mais das despesas comuns", ela transfere, o acerto fica registrado, e o próximo período começa zerado.

---

## Anexos e infraestrutura

### `receipts`

| Coluna | Tipo | Notas |
|---|---|---|
| `uploaded_by` | uuid NOT NULL | |
| `storage_path` | text NOT NULL | `{household_id}/{receipt_id}.jpg` |
| `thumbnail_path` | text | |
| `mime_type` / `byte_size` | | |
| `captured_at` | timestamptz | |
| `ocr_status` | text NOT NULL | `pending` · `processing` · `done` · `failed` · `skipped` |
| `ocr_text` | text | texto bruto |
| `ocr_parsed` | jsonb | `{total_cents, date, merchant, cnpj, items[], confidence}` |
| `ocr_confidence` | numeric(4,3) | |
| `transaction_id` | uuid | |
| `local_only` | boolean NOT NULL | ainda não subiu |

O caminho no Storage **começa pelo `household_id`** — é isso que permite a política de Storage autorizar por `split_part(name, '/', 1)`. Não é estético, é o mecanismo de segurança.

### `devices`

`user_id`, `platform`, `model`, `push_token`, `app_version`, `last_sync_at`, `last_seen_at`. Serve para push e para a tela "dispositivos conectados". Não tem `household_id` — é do usuário.

### Locais, fora do Supabase

Existem só no SQLite e **nunca sincronizam**:

- **`outbox`** — fila de push. `id`, `table_name`, `row_id`, `operation`, `payload`, `attempts`, `last_error`, `created_at`.
- **`sync_state`** — cursor por tabela. `table_name`, `last_pulled_at`, `last_pushed_at`.
- **`upload_queue`** — fila de fotos. `receipt_id`, `local_path`, `attempts`, `last_error`.
- **`app_settings`** — tema, biometria, filtros salvos, categorias favoritas.

---

## Índices obrigatórios

Sem estes, a lista de lançamentos engasga já no primeiro ano:

```sql
create index on transactions (household_id, occurred_at desc) where deleted_at is null;
create index on transactions (account_id, occurred_at desc)   where deleted_at is null;
create index on transactions (household_id, category_id, occurred_at) where deleted_at is null;
create index on transactions (household_id, member_id, occurred_at)   where deleted_at is null;
create index on transactions (installment_group_id) where installment_group_id is not null;
create index on transactions (transfer_group_id)    where transfer_group_id is not null;
create index on transaction_splits (transaction_id);
create index on merchants (household_id, normalized_name);
create index on payslip_items (payslip_id);

-- o índice do sync, em TODA tabela sincronizável:
create index on <tabela> (household_id, updated_at);
```

O último é o mais importante do sistema. Todo pull é `WHERE household_id = ? AND updated_at > ?`, em toda tabela, a cada sincronização. Índices parciais com `where deleted_at is null` ficam menores e mais rápidos, já que praticamente toda leitura filtra assim.

---

## Views

Todas criadas com `security_invoker = on`, para que a RLS de quem consulta seja aplicada. **Sem isso a view roda como o dono e vaza dado entre casas** — é a falha de segurança clássica de view no Supabase.

| View | Entrega |
|---|---|
| `v_account_balances` | Saldo atual por conta = abertura + soma dos lançamentos |
| `v_member_month` | **Comparativo do casal**: por membro e mês → receita, despesa, saldo |
| `v_category_month` | Gasto por categoria e mês, com percentual do total |
| `v_budget_progress` | Orçamento vs realizado, percentual consumido, dias restantes |
| `v_credit_card_bill` | Fatura por ciclo, respeitando `statement_closing_day` |
| `v_upcoming_bills` | Contas fixas dos próximos 30 dias |
| `v_household_net_worth` | Soma das contas com `include_in_totals` |
| `v_split_integrity` | Diagnóstico: splits que não fecham com o total |

`v_member_month` é a view que justifica ter escolhido Postgres. Ela responde a pergunta central do produto numa query só:

```sql
select member_id, date_trunc('month', occurred_at) as month,
       sum(amount_cents) filter (where kind = 'income')  as income_cents,
       sum(amount_cents) filter (where kind = 'expense') as expense_cents,
       sum(signed_amount_cents) filter (where kind in ('income','expense')) as net_cents
from transactions
where deleted_at is null and visibility = 'household'
group by 1, 2;
```

O `filter (where ...)` é sintaxe SQL padrão que o Postgres suporta e o SQLite (3.30+) também — a mesma query roda nos dois lados, o que evita manter duas lógicas de relatório.
