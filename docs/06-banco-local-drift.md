# 06 — Banco Local (Drift / SQLite)

O SQLite é a **única** fonte de dados da interface. Nenhum widget, provider ou repositório de leitura fala com o Supabase. O sync escreve aqui; o Drift emite no `Stream`; a tela se atualiza sozinha.

## Regras de espelhamento

O schema local reproduz o remoto com quatro diferenças deliberadas:

| Postgres | Drift | Por quê |
|---|---|---|
| `uuid` | `TextColumn` | SQLite não tem tipo UUID. Guardar como texto canônico minúsculo |
| `timestamptz` | `DateTimeColumn` | Drift grava como epoch em inteiro. **Sempre UTC** — converter para local só na formatação |
| `text[]` (`tags`) | `TextColumn` com JSON | SQLite não tem array. `TypeConverter` faz `List<String>` ⇄ JSON |
| `signed_amount_cents` gerada | coluna comum, calculada na escrita | Coluna gerada existe no SQLite, mas o Drift não a expõe bem; calcular no mapper é mais simples |

Além disso, o local tem quatro tabelas que **nunca sincronizam**: `outbox`, `sync_state`, `upload_queue`, `app_settings`.

Regra de ouro: **nome de coluna idêntico ao Postgres, em `snake_case`.** O Drift gera getters `camelCase` a partir disso automaticamente. Se os nomes divergirem, cada mapper vira tradução manual e um erro de digitação some no sync sem estourar em lugar nenhum.

## Tabelas

`lib/data/local/tables/` — uma por arquivo.

```dart
// lib/data/local/tables/shared.dart
import 'package:drift/drift.dart';

/// Colunas presentes em toda tabela sincronizável.
///
/// Drift resolve mixin de coluna em tempo de compilação, então isto
/// não custa nada em runtime e garante que nenhuma tabela nova esqueça
/// o conjunto — esquecimento que o sync não denuncia, só ignora.
mixin SyncedTable on Table {
  TextColumn get id => text()();
  TextColumn get householdId => text().named('household_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  IntColumn get syncVersion =>
      integer().named('sync_version').withDefault(const Constant(0))();

  /// Marca escrita local ainda não confirmada pelo servidor. É o que
  /// permite o conflito ser resolvido a favor do dispositivo quando a
  /// alteração local ainda não subiu. Ver 07-sync-engine.md.
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// lib/data/local/tables/transactions.dart
import 'package:drift/drift.dart';
import 'shared.dart';
import '../converters/string_list_converter.dart';

class Transactions extends Table with SyncedTable {
  TextColumn get accountId => text().named('account_id')();
  TextColumn get categoryId => text().named('category_id').nullable()();
  TextColumn get memberId => text().named('member_id').nullable()();
  TextColumn get createdBy => text().named('created_by')();

  TextColumn get kind => text()();          // expense|income|transfer_out|transfer_in
  IntColumn get amountCents => integer().named('amount_cents')();

  /// Espelha a coluna gerada do Postgres. Calculada no mapper e em
  /// `TransactionsCompanion.build`; nunca preenchida à mão pela UI.
  IntColumn get signedAmountCents => integer().named('signed_amount_cents')();

  TextColumn get currency => text().withDefault(const Constant('BRL'))();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  TextColumn get description => text().nullable()();
  TextColumn get merchantId => text().named('merchant_id').nullable()();
  TextColumn get paymentMethod => text().named('payment_method').nullable()();

  IntColumn get installmentNo => integer().named('installment_no').nullable()();
  IntColumn get installmentTotal => integer().named('installment_total').nullable()();
  TextColumn get installmentGroupId =>
      text().named('installment_group_id').nullable()();
  TextColumn get transferGroupId => text().named('transfer_group_id').nullable()();
  TextColumn get recurrenceId => text().named('recurrence_id').nullable()();
  TextColumn get receiptId => text().named('receipt_id').nullable()();

  TextColumn get status => text().withDefault(const Constant('cleared'))();
  TextColumn get visibility => text().withDefault(const Constant('household'))();
  BoolColumn get isReimbursable =>
      boolean().named('is_reimbursable').withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}
```

O `TypeConverter` das tags:

```dart
// lib/data/local/converters/string_list_converter.dart
class StringListConverter extends TypeConverter<List<String>, String>
    with JsonTypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
```

As demais tabelas seguem o mesmo padrão. A lista completa a criar: `Households`, `HouseholdMembers`, `Accounts`, `Categories`, `Merchants`, `Transactions`, `TransactionSplits`, `Budgets`, `Goals`, `GoalContributions`, `Recurrences`, `Payslips`, `PayslipItems`, `Receipts`, `Settlements`, `Profiles`.

## Tabelas locais puras

```dart
/// Fila de push. Cada escrita local enfileira aqui NA MESMA transação
/// SQLite em que grava o dado — não pode existir estado em que gravou
/// e não enfileirou.
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get tableName => text().named('table_name')();
  TextColumn get rowId => text().named('row_id')();
  TextColumn get operation => text()();          // upsert | delete
  TextColumn get payload => text()();            // JSON pronto para PostgREST
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get nextAttemptAt =>
      dateTime().named('next_attempt_at').nullable()();
}

/// Cursor por tabela. Chave é o nome da tabela.
class SyncState extends Table {
  TextColumn get tableName => text().named('table_name')();
  DateTimeColumn get lastPulledAt => dateTime().named('last_pulled_at').nullable()();
  DateTimeColumn get lastPushedAt => dateTime().named('last_pushed_at').nullable()();
  @override
  Set<Column> get primaryKey => {tableName};
}

/// Fila de upload de foto. Separada da outbox porque binário tem
/// política de retry diferente: mais lenta, e só em Wi-Fi se o usuário
/// preferir.
class UploadQueue extends Table {
  TextColumn get receiptId => text().named('receipt_id')();
  TextColumn get localPath => text().named('local_path')();
  TextColumn get storagePath => text().named('storage_path')();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  @override
  Set<Column> get primaryKey => {receiptId};
}

/// Chave-valor para preferências. Vive aqui e não em SharedPreferences
/// para que tema e filtros possam ser lidos na mesma transação que o
/// resto, sem await extra no boot.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
```

## A classe do banco

```dart
// lib/data/local/database.dart
@DriftDatabase(
  tables: [
    Profiles, Households, HouseholdMembers, Accounts, Categories, Merchants,
    Transactions, TransactionSplits, Budgets, Goals, GoalContributions,
    Recurrences, Payslips, PayslipItems, Receipts, Settlements,
    Outbox, SyncState, UploadQueue, AppSettings,
  ],
  daos: [
    TransactionDao, AccountDao, CategoryDao, BudgetDao, ReportDao,
    RecurrenceDao, PayslipDao, ReceiptDao, HouseholdDao, SyncDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        beforeOpen: (details) async {
          // Sem isto, ON DELETE CASCADE é silenciosamente ignorado —
          // o SQLite desliga chaves estrangeiras por padrão, em cada
          // conexão.
          await customStatement('PRAGMA foreign_keys = ON');
          // WAL: leitura não bloqueia escrita. Importante porque o
          // sync grava enquanto a lista está sendo rolada.
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
        },
      );

  Future<void> _createIndexes() async {
    // Os mesmos índices do Postgres. Uma lista com 5 mil lançamentos
    // sem estes leva segundos para abrir.
    const stmts = [
      'CREATE INDEX IF NOT EXISTS tx_by_date ON transactions '
          '(household_id, occurred_at DESC) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS tx_by_account ON transactions '
          '(account_id, occurred_at DESC) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS tx_by_category ON transactions '
          '(household_id, category_id, occurred_at) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS tx_by_member ON transactions '
          '(household_id, member_id, occurred_at) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS tx_dirty ON transactions (is_dirty) '
          'WHERE is_dirty = 1',
      'CREATE INDEX IF NOT EXISTS splits_by_tx ON transaction_splits '
          '(transaction_id) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS outbox_next ON outbox (next_attempt_at)',
    ];
    for (final s in stmts) {
      await customStatement(s);
    }
  }

  static QueryExecutor _open() => driftDatabase(
        name: 'financa',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      );
}
```

`shareAcrossIsolates: true` importa: o `workmanager` roda o sync em background num isolate separado, e sem isso as duas conexões brigam e o SQLite devolve `database is locked`.

## DAOs

Um por agregado. O DAO é onde o SQL mora — repositório não escreve query.

```dart
// lib/data/local/daos/transaction_dao.dart
@DriftAccessor(tables: [Transactions, TransactionSplits, Accounts, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Lista reativa. A UI observa isto e nunca chama a rede.
  Stream<List<TransactionWithRefs>> watchByMonth({
    required String householdId,
    required DateTime month,
    String? memberId,
    String? accountId,
    String? categoryId,
  }) {
    final start = DateTime.utc(month.year, month.month);
    final end = DateTime.utc(month.year, month.month + 1);

    final q = select(transactions).join([
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..where(transactions.householdId.equals(householdId))
      ..where(transactions.deletedAt.isNull())
      ..where(transactions.occurredAt.isBiggerOrEqualValue(start))
      ..where(transactions.occurredAt.isSmallerThanValue(end))
      ..orderBy([
        OrderingTerm.desc(transactions.occurredAt),
        OrderingTerm.desc(transactions.createdAt),
      ]);

    if (memberId != null) q.where(transactions.memberId.equals(memberId));
    if (accountId != null) q.where(transactions.accountId.equals(accountId));
    if (categoryId != null) q.where(transactions.categoryId.equals(categoryId));

    return q.watch().map((rows) => rows.map(TransactionWithRefs.fromRow).toList());
  }

  /// Saldo por conta. Calculado, nunca armazenado — ver 01-arquitetura.md.
  Stream<Map<String, int>> watchBalances(String householdId) {
    final sum = transactions.signedAmountCents.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.accountId, sum])
      ..where(transactions.householdId.equals(householdId))
      ..where(transactions.deletedAt.isNull())
      ..groupBy([transactions.accountId]);

    return q.watch().map({
      for (final r in _) r.read(transactions.accountId)!: r.read(sum) ?? 0,
    }.let);   // ver nota abaixo
  }

  /// Grava e enfileira, atomicamente. É o único caminho de escrita.
  Future<void> upsertLocal(TransactionsCompanion entry) =>
      transaction(() async {
        await into(transactions).insertOnConflictUpdate(entry);
        await db.syncDao.enqueue(
          table: 'transactions',
          rowId: entry.id.value,
          operation: 'upsert',
        );
      });

  /// Soft delete: marca, não apaga. Delete físico não propaga para um
  /// dispositivo que esteve offline — ele ressuscitaria a linha no
  /// próximo push.
  Future<void> softDelete(String id) => transaction(() async {
        await (update(transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            deletedAt: Value(DateTime.now().toUtc()),
            isDirty: const Value(true),
          ),
        );
        await db.syncDao.enqueue(
          table: 'transactions', rowId: id, operation: 'upsert');
      });
}
```

> Nota para o executor: o corpo de `watchBalances` acima está esquemático quanto à conversão do resultado. Implemente com `q.watch().map((rows) { final m = <String,int>{}; for (final r in rows) { ... } return m; })`. O que importa é a forma da query, não o açúcar.

## Consultas que precisam de SQL cru

Relatórios com `FILTER (WHERE ...)` e window function não têm equivalente no builder do Drift. Use `customSelect`, que é suportado e continua reativo:

```dart
/// Comparativo entre membros — espelha v_member_month do Postgres.
/// Mesma query dos dois lados: uma lógica de relatório só, não duas.
Stream<List<MemberMonthRow>> watchMemberComparison({
  required String householdId,
  required DateTime month,
}) {
  return customSelect(
    '''
    SELECT m.id                AS member_id,
           m.display_name      AS member_name,
           m.color             AS member_color,
           COALESCE(SUM(t.amount_cents) FILTER (WHERE t.kind = 'income'), 0)
                               AS income_cents,
           COALESCE(SUM(t.amount_cents) FILTER (WHERE t.kind = 'expense'), 0)
                               AS expense_cents,
           COALESCE(SUM(t.signed_amount_cents)
                    FILTER (WHERE t.kind IN ('income','expense')), 0)
                               AS net_cents
    FROM household_members m
    LEFT JOIN transactions t
      ON  t.member_id    = m.id
      AND t.deleted_at   IS NULL
      AND t.visibility   = 'household'
      AND t.occurred_at >= ? AND t.occurred_at < ?
    WHERE m.household_id = ? AND m.deleted_at IS NULL
    GROUP BY m.id, m.display_name, m.color
    ORDER BY expense_cents DESC
    ''',
    variables: [
      Variable.withDateTime(start),
      Variable.withDateTime(end),
      Variable.withString(householdId),
    ],
    readsFrom: {transactions, householdMembers},   // ← sem isto não é reativo
  ).watch().map((rows) => rows.map(MemberMonthRow.fromData).toList());
}
```

`readsFrom` é obrigatório em `customSelect`: é o que diz ao Drift quais tabelas invalidam o `Stream`. Esquecer isso produz uma tela que carrega certo e nunca mais atualiza — bug que parece de cache e leva horas para achar.

`FILTER (WHERE ...)` funciona em SQLite 3.30+. O `sqlite3_flutter_libs` embarca uma versão bem mais nova, então é seguro, e a query fica idêntica à do Postgres.

## Migrations locais

Toda mudança de schema exige subir `schemaVersion` e escrever o passo:

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) {
    await m.addColumn(transactions, transactions.isReimbursable);
  }
  if (from < 3) {
    await m.createTable(settlements);
  }
  await _createIndexes();   // idempotente por causa do IF NOT EXISTS
},
```

Gere o teste de migration com a ferramenta do próprio Drift:

```bash
dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/drift/generated/
```

Isso cria testes que sobem cada versão a partir da anterior com dados dentro. Migration de banco local que corrompe dado é irreversível no celular do usuário — não existe rollback lá. Esses testes são a única rede.

**Alternativa sempre disponível:** se uma migration local ficar complicada demais, apagar o banco e ressincronizar do servidor é aceitável. O SQLite local é cache, não fonte da verdade. A única coisa que se perde é o que estiver na `outbox` e ainda não subiu — então antes de apagar, force um push e confira que a outbox está vazia.

## Codegen

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # durante o desenvolvimento
```

Arquivos `.g.dart` e `.freezed.dart` ficam fora do git (já no `.gitignore`). Todo clone precisa rodar o build_runner antes do primeiro `flutter run` — coloque isso no README do projeto.
