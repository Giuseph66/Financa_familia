# E05 — Banco Local

Referências: [06-banco-local-drift.md](../06-banco-local-drift.md), [02-modelo-de-dados.md](../02-modelo-de-dados.md)

## Tarefas

### 1. Tabelas

`lib/data/local/tables/`, uma por arquivo. Comece por `shared.dart` com o mixin `SyncedTable`.

Todas as 16 sincronizáveis: `Profiles`, `Households`, `HouseholdMembers`, `Accounts`, `Categories`, `Merchants`, `Transactions`, `TransactionSplits`, `Budgets`, `Goals`, `GoalContributions`, `Recurrences`, `Payslips`, `PayslipItems`, `Receipts`, `Settlements`.

E as 4 locais: `Outbox`, `SyncState`, `UploadQueue`, `AppSettings`.

**Nome de coluna idêntico ao Postgres, em `snake_case`.** Divergência aqui vira erro de mapeamento que o sync engole em silêncio — não estoura, só deixa de sincronizar aquele campo.

### 2. Conversores

`lib/data/local/converters/string_list_converter.dart` para as `tags`. SQLite não tem array; guarda JSON.

### 3. A classe do banco

`database.dart` com `@DriftDatabase`, `schemaVersion = 1`, e o `beforeOpen` que liga `foreign_keys`, `journal_mode = WAL` e `synchronous = NORMAL`.

`PRAGMA foreign_keys = ON` é por conexão e desligado por padrão no SQLite. Sem ele, `ON DELETE CASCADE` é silenciosamente ignorado.

`shareAcrossIsolates: true` no `driftDatabase`, porque o sync em background roda em outro isolate e sem isso o SQLite devolve `database is locked`.

### 4. Índices

`_createIndexes()`, chamado em `onCreate` e em `onUpgrade`, com `IF NOT EXISTS`. A lista está em [06-banco-local-drift.md](../06-banco-local-drift.md#a-classe-do-banco).

### 5. DAOs

Um por agregado. É onde o SQL mora — repositório não escreve query.

- `TransactionDao` — `watchByMonth`, `watchBalances`, `upsertLocal`, `softDelete`, `mostUsedCategory`
- `AccountDao`, `CategoryDao`, `MerchantDao`
- `BudgetDao`, `RecurrenceDao`, `PayslipDao`, `ReceiptDao`, `HouseholdDao`
- `ReportDao` — as queries de relatório em `customSelect`
- `SyncDao` — outbox, cursor, aplicar linha remota

**Todo método de leitura devolve `Stream`**, não `Future`. É o que faz a UI se atualizar sozinha quando o sync grava. Um `Future` numa tela de lista significa que ela nunca reage à sincronização.

Em `customSelect`, sempre preencha `readsFrom`. Esquecer produz uma tela que carrega certo e nunca mais atualiza — bug que parece de cache e leva horas para achar.

### 6. Repositórios

`lib/data/repositories/` implementando as interfaces de `lib/domain/repositories/`.

A regra que não se quebra:

```dart
Future<void> create(TransactionsCompanion tx) => _db.transaction(() async {
  await _dao.insert(tx);
  await _syncDao.enqueue('transactions', tx.id.value, 'upsert');
});
```

Gravar dado e enfileirar na outbox **na mesma transação SQLite**. Não pode existir estado em que gravou e não enfileirou — é o que o teste "matar o app no meio do push" verifica.

### 7. Providers

```dart
@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
```

`keepAlive` porque abrir e fechar o banco a cada tela é caro e perde o WAL.

### 8. Testes

`test/data/` com `NativeDatabase.memory()`. Cubra o cenário de saldo com transferência de [17-testes.md](../17-testes.md#testes-de-banco) — é o que valida a decisão dos quatro `kind`.

Gere os testes de migration:

```bash
dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/drift/generated/
```

## DoD

- [ ] `dart run build_runner build` sem erro
- [ ] As 20 tabelas criadas
- [ ] Toda coluna com o mesmo nome do Postgres
- [ ] `PRAGMA foreign_keys` ativo — teste que `ON DELETE CASCADE` funciona
- [ ] Todo DAO de leitura devolve `Stream`
- [ ] Todo `customSelect` tem `readsFrom`
- [ ] Gravar lançamento cria linha na outbox, na mesma transação
- [ ] Teste de saldo com transferência passa: contas movem, relatório não conta como despesa
- [ ] Testes de migration gerados e passando
- [ ] Inserir 5.000 lançamentos e abrir a lista em menos de 500ms

Commit: `feat(e05): banco local com drift`
