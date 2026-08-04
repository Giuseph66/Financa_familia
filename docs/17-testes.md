# 17 — Testes

## O que testar, e o que não

Cobertura como número não é meta. O critério é: **testar o que causa dano quando quebra.**

| Área | Nível | Obrigatório |
|---|---|---|
| `Money` (formatar, parsear, arredondar) | unitário | Sim |
| Cálculo de próximo vencimento | unitário | Sim |
| Parser de recibo | unitário | Sim |
| Resolução de conflito do sync | unitário | Sim |
| Ciclo de fatura de cartão | unitário | Sim |
| DAOs e queries de relatório | integração (SQLite em memória) | Sim |
| Migrations locais | integração | Sim |
| Entrada rápida (3 toques) | widget + integração | Sim |
| Políticas de RLS | SQL, no servidor | Sim |
| Componentes do design system | golden | Recomendado |
| Demais telas | widget | Onde houver lógica |

Tela que só monta widget a partir de um provider não precisa de teste — o teste repetiria a implementação e quebraria a cada ajuste de layout, sem nunca pegar bug real.

## Unitários que não podem faltar

### Money

```dart
test('nunca usa ponto flutuante', () {
  // 0.1 + 0.2 = 0.30000000000000004. Em 300 lançamentos isso vira
  // centavos que ninguém consegue explicar. Este teste existe para
  // travar qualquer refactor que introduza double.
  expect(Money(10) + Money(20), Money(30));
  expect((Money(1) * 3).cents, 3);
});

test('formata em pt_BR', () {
  expect(Money(123456).formatted, 'R\$ 1.234,56');
  expect(Money(-4590).formatted,  '-R\$ 45,90');
  expect(Money(0).formatted,      'R\$ 0,00');
  expect(Money(100000000).formatted, 'R\$ 1.000.000,00');
});

test('parseia entrada do usuário', () {
  expect(Money.parse('1.234,56').cents, 123456);
  expect(Money.parse('1234,56').cents,  123456);
  expect(Money.parse('R\$ 45').cents,     4500);
  expect(Money.parse('abc'), isNull);
});

test('divisão distribui o resto', () {
  // R$ 10,00 entre 3 pessoas: 3,34 + 3,33 + 3,33. Somar de volta TEM
  // que dar exatamente 1000. Perder um centavo no rateio é a
  // reclamação clássica de app de divisão de conta.
  final parts = Money(1000).split(3);
  expect(parts.map((p) => p.cents).toList(), [334, 333, 333]);
  expect(parts.fold(0, (s, p) => s + p.cents), 1000);
});
```

### Recorrência

```dart
test('dia 31 em mês de 30 dias cai no último dia', () {
  expect(
    nextDue(from: DateTime(2026, 3, 31), frequency: Frequency.monthly,
            interval: 1, dayOfMonth: 31),
    DateTime(2026, 4, 30),   // não 1º de maio
  );
});

test('dia 31 em fevereiro', () {
  expect(
    nextDue(from: DateTime(2026, 1, 31), frequency: Frequency.monthly,
            interval: 1, dayOfMonth: 31),
    DateTime(2026, 2, 28),
  );
});

test('29 de fevereiro de bissexto para não bissexto', () {
  expect(
    nextDue(from: DateTime(2024, 2, 29), frequency: Frequency.yearly,
            interval: 1, dayOfMonth: 29),
    DateTime(2025, 2, 28),
  );
});
```

### Parser de recibo

Guarde amostras reais em `test/fixtures/receipts/*.txt` — texto já extraído, para o teste não depender do ML Kit. Cubra: cupom de mercado, comprovante de Pix, nota de posto, recibo com desconto (onde o subtotal é maior que o total), e um cupom com OCR ruim onde o esperado é `null` e não um chute.

## Testes de banco

```dart
late AppDatabase db;

setUp(() {
  // NativeDatabase.memory() é isolado por teste e rápido. Não use
  // arquivo: testes passam a depender de ordem de execução.
  db = AppDatabase.forTesting(NativeDatabase.memory());
});
tearDown(() => db.close());

test('saldo soma corretamente com transferência', () async {
  // Transferência não pode contar como receita nem despesa, mas TEM
  // que mover o saldo das duas contas. É o teste que valida a decisão
  // dos quatro kinds em vez de três.
  await db.seedAccount(id: 'a', opening: 100000);
  await db.seedAccount(id: 'b', opening: 0);
  await db.seedTransfer(from: 'a', to: 'b', cents: 30000);

  final balances = await db.transactionDao.balances('house');
  expect(balances['a'], 70000);
  expect(balances['b'], 30000);

  final report = await db.reportDao.monthSummary('house', DateTime.now());
  expect(report.expenseCents, 0);   // transferência não é despesa
  expect(report.incomeCents,  0);
});
```

### Migrations

```bash
dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/drift/generated/
```

Isso gera testes que sobem cada versão a partir da anterior, com dados dentro. **Migration local que corrompe dado é irreversível no celular do usuário** — não existe rollback lá. Esses testes são a única rede.

## Testes de sync

Os mais importantes e os mais esquecidos. Precisam de dois bancos locais e um Supabase falso.

```dart
test('criar offline nos dois dispositivos preserva ambos', () async {
  // IDs gerados no cliente (UUID v7) tornam criações livres de
  // conflito por construção. Este teste é o que prova isso.
  final a = TestDevice(), b = TestDevice();
  a.goOffline(); b.goOffline();

  await a.createTransaction(cents: 1000);
  await b.createTransaction(cents: 2000);

  a.goOnline(); await a.sync();
  b.goOnline(); await b.sync();
  await a.sync();

  expect(await a.transactionCount(), 2);
  expect(await b.transactionCount(), 2);
});

test('app morto no meio do push não duplica nem perde', () async {
  // Valida a decisão de gravar dado e outbox na MESMA transação
  // SQLite. Se a implementação separar em dois awaits, este teste
  // falha — que é exatamente o objetivo dele.
  final d = TestDevice();
  await d.createTransaction(cents: 1000);
  d.killDuringPush();
  await d.restart();
  await d.sync();

  expect(await d.server.transactionCount(), 1);
  expect(await d.outboxCount(), 0);
});

test('delete propaga para dispositivo que estava offline', () async {
  // O teste que justifica soft delete. Com delete físico, B
  // ressuscitaria a linha no push seguinte.
  ...
});
```

A tabela completa de cenários obrigatórios está em [07-sync-engine.md](07-sync-engine.md).

## Testes de RLS

Rodam em SQL, contra o Supabase local (`supabase start`). Escreva em `supabase/tests/rls_test.sql` e rode com `supabase test db`.

Os casos estão em [05-rls-seguranca.md](05-rls-seguranca.md). Todos são bloqueantes: qualquer falha impede o release, sem exceção e sem "conserto depois".

## Teste de integração da entrada rápida

O que mede a promessa central do produto:

```dart
testWidgets('registra despesa em 3 toques', (tester) async {
  await tester.pumpWidget(const App());
  await tester.tap(find.byKey(const Key('fab_quick_add')));
  await tester.pumpAndSettle();

  final sw = Stopwatch()..start();

  // Toque 1: valor (a sequência de dígitos é um gesto contínuo)
  for (final d in ['3','2','9','0']) {
    await tester.tap(find.byKey(Key('key_$d')));
  }
  // Toque 2: categoria
  await tester.tap(find.byKey(const Key('cat_food.market')));
  // Toque 3: salvar
  await tester.tap(find.byKey(const Key('btn_save')));
  await tester.pumpAndSettle();

  sw.stop();
  expect(sw.elapsedMilliseconds, lessThan(5000));
  expect(find.text('R\$ 32,90'), findsOneWidget);
});
```

## Golden tests

Para os componentes do design system, nos dois temas e em duas escalas de fonte:

```dart
testGoldens('TransactionTile em todas as variantes', (tester) async {
  await tester.pumpWidgetBuilder(
    GoldenBuilder.column()
      ..addScenario('despesa',       const TransactionTile(...))
      ..addScenario('receita',       const TransactionTile(...))
      ..addScenario('transferência', const TransactionTile(...))
      ..addScenario('com recibo',    const TransactionTile(...))
      ..addScenario('não sincronizado', const TransactionTile(...))
      ..addScenario('valor longo',   const TransactionTile(cents: 999999999))
      ..build(),
  );
  await screenMatchesGolden(tester, 'transaction_tile');
});
```

Golden pega o que revisão de código não pega: o valor de R$ 9.999.999,99 estourando o layout, o texto sumindo no tema escuro, o ícone desalinhado com `fontScale = 1.5`.

Regenere com `flutter test --update-goldens` e **olhe o diff da imagem** antes de aceitar. Aceitar golden no automático anula a razão de existirem.

## Antes de cada release

```bash
flutter analyze                      # zero issues
dart run custom_lint                 # zero issues
flutter test                         # tudo verde
flutter test integration_test/       # em device real
supabase test db                     # RLS
flutter build apk --release          # compila
```

Manual, num aparelho de verdade:

- [ ] Modo avião: registrar 5 lançamentos, restaurar rede, conferir que os 5 chegaram
- [ ] Dois aparelhos: lançar em um, aparecer no outro em menos de 10s
- [ ] Widget atualiza depois do lançamento
- [ ] Foto de cupom real do mercado
- [ ] Tema escuro em todas as telas
- [ ] Escala de fonte em 200%
- [ ] Aparelho pequeno (320dp de largura)
- [ ] Biometria bloqueia e desbloqueia
