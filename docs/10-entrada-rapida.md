# 10 — Entrada Rápida

A tela mais importante do app. Se ela for lenta, nada mais importa: o usuário para de registrar e o produto morre.

## A meta

**3 toques, menos de 5 segundos**, do abrir ao salvo, no caso comum (uma despesa com valor e categoria).

Isso é requisito com número, medido em teste de integração e verificado no DoD. Não é aspiração.

## O fluxo

```
┌──────────────────────────────┐
│  Despesa | Receita | Transf. │  ← segmentado, Despesa já selecionado
├──────────────────────────────┤
│                              │
│         R$ 32,90             │  ← enorme, tabular, foco imediato
│                              │
├──────────────────────────────┤
│  🛒   🍔   ⛽   🏠   💊   🎬  │  ← 6 favoritas + "mais"
│  🚗   📱   👕   🎁   ➕      │
├──────────────────────────────┤
│  [Nubank ▾]  [Hoje ▾]  [Eu ▾]│  ← chips, já preenchidos
├──────────────────────────────┤
│  1   2   3                   │
│  4   5   6      ⌫            │  ← teclado próprio
│  7   8   9                   │
│  ,   0   00     ✓ Salvar     │
└──────────────────────────────┘
```

Toque 1: digitar o valor (várias teclas, mas é um gesto contínuo).
Toque 2: a categoria.
Toque 3: salvar.

Conta, data e membro **já vêm preenchidos** e só são tocados quando o padrão está errado — o que é minoria dos casos.

## Decisões de interface

**Valor primeiro, sempre.** É o único campo obrigatório de verdade e o que o usuário tem na cabeça saindo do caixa. Pedir categoria antes obriga a segurar o número na memória enquanto navega, e é onde a pessoa desiste.

**Teclado próprio, não `TextField` com `keyboardType: number`.** O teclado do sistema demora a subir, muda de layout entre aparelhos, e traz teclas inúteis. O nosso tem `00` (que economiza dois toques em valor redondo), teclas de 64dp de altura e resposta tátil. Também garante que não existe estado inválido: não dá para digitar duas vírgulas nem letra.

**Sem campo de descrição visível.** Ele existe, atrás de "Mais detalhes". A descrição é opcional e a maioria dos lançamentos não precisa: "🛒 R$ 32,90 · Hoje" já diz tudo. Um campo de texto visível é um convite psicológico a preenchê-lo, e é exatamente o atrito que o app quer eliminar.

**Salvar sempre visível e sempre habilitado** depois que há valor. Nada de botão desabilitado enquanto faltam campos — o único campo que falta é o valor, e sem valor o botão nem aparece.

## Padrões inteligentes

A qualidade dos chutes é o que faz os 3 toques valerem. Ordem de precedência da categoria:

```dart
/// Camada zero de inteligência: frequência pura, offline, sem IA.
/// Resolve a maioria dos casos de graça. A IA de 16-ia-futuro.md só
/// entra onde isto não alcança.
Future<String?> suggestCategory({String? merchantText, required DateTime when}) async {
  // 1. Estabelecimento conhecido → a categoria que ele sempre recebe.
  //    O sinal mais forte que existe, e é só um SELECT.
  if (merchantText != null) {
    final m = await merchantDao.findByNormalized(normalize(merchantText));
    if (m?.defaultCategoryId != null) return m!.defaultCategoryId;
  }

  // 2. Horário. Gasto às 12h30 num dia útil é almoço com alta
  //    probabilidade; às 20h de sexta, provavelmente não.
  final byHour = await transactionDao.mostUsedCategoryInHourWindow(
    hour: when.hour, windowHours: 2, isWeekend: when.weekday > 5,
  );
  if (byHour != null) return byHour;

  // 3. A mais usada nos últimos 30 dias.
  return transactionDao.mostUsedCategory(days: 30);
}
```

Conta padrão: a última usada nesse tipo de lançamento. Quem paga mercado sempre no débito e assinatura sempre no crédito acerta nas duas sem tocar no chip.

Data padrão: hoje. Depois das 22h, oferece "hoje" e "ontem" lado a lado — registro noturno frequentemente se refere ao dia que acabou.

Membro padrão: você.

### As categorias favoritas

O grid mostra 6, escolhidas por um escore que mistura frequência e recência:

```dart
// Frequência sozinha congela o grid nas categorias do primeiro mês.
// Recência sozinha oscila demais. O produto das duas adapta sem
// tremer: uma categoria nova e intensa sobe rápido, uma antiga e
// abandonada desce devagar.
score = uses_last_60d * (1.0 / (1 + days_since_last_use))
```

O usuário pode fixar categorias em Ajustes; fixadas vêm primeiro e não saem.

## Implementação

```dart
// lib/features/quick_add/presentation/controllers/quick_add_controller.dart
@riverpod
class QuickAddController extends _$QuickAddController {
  @override
  QuickAddState build({String? presetCategoryId, TransactionKind? presetKind}) {
    // Deep link do widget pode pré-selecionar. Ver 12-widgets-e-atalhos.md.
    return QuickAddState.initial(
      kind: presetKind ?? TransactionKind.expense,
      categoryId: presetCategoryId,
    );
  }

  void appendDigit(String d) {
    // Valor sempre em centavos, montado da direita para a esquerda:
    // digitar 3, 2, 9, 0 produz 3290 = R$ 32,90. Nunca existe estado
    // intermediário inválido, e não há parsing de string para double
    // em lugar nenhum.
    final next = state.amountCents * 10 + int.parse(d);
    if (next > 99999999999) return;   // teto de R$ 999.999.999,99
    state = state.copyWith(amountCents: next);
  }

  Future<void> save() async {
    if (state.amountCents <= 0) return;

    final tx = TransactionsCompanion.insert(
      id: newId(),                                  // UUID v7 no cliente
      householdId: state.householdId,
      accountId: state.accountId,
      createdBy: state.userId,
      kind: state.kind.name,
      amountCents: state.amountCents,
      signedAmountCents: state.kind.sign * state.amountCents,
      occurredAt: state.occurredAt,
      categoryId: Value(state.categoryId),
      memberId: Value(state.memberId),
      description: Value(state.description),
      merchantId: Value(await _resolveMerchant()),
      source: const Value('quick_add'),
      isDirty: const Value(true),
    );

    // Grava no SQLite e enfileira na outbox NA MESMA transação.
    // A UI já atualizou antes de qualquer rede acontecer.
    await ref.read(transactionRepositoryProvider).create(tx);

    // Aprende: incrementa o contador do estabelecimento e fixa a
    // categoria escolhida como padrão dele. É isto que faz a sugestão
    // melhorar sozinha com o uso.
    await _learnFromEntry();

    // Sync é disparado com debounce de 3s, sem bloquear a UI. Quem
    // lança cinco coisas seguidas gera um sync, não cinco.
    ref.read(syncEngineProvider).requestSync();

    HapticFeedback.mediumImpact();
    ref.read(homeWidgetServiceProvider).refresh();   // atualiza o widget
  }
}
```

## Depois de salvar

A folha fecha e aparece uma barra:

```
✓ R$ 32,90 · Mercado          [Desfazer]  [+ Outro]
```

Cinco segundos. Dois botões que importam:

**Desfazer** — soft delete imediato, sem confirmação. Muito mais barato que um diálogo "tem certeza?" em toda gravação, e cobre o erro real (categoria errada, valor errado) melhor: a pessoa desfaz e refaz em dois segundos.

**+ Outro** — reabre a folha mantendo conta, data e membro, zerando só o valor. Registrar cinco itens de uma feira vira uma sequência fluida em vez de cinco aberturas.

## Modos alternativos de entrada

**Foto do recibo** — botão de câmera no canto. Ver [11-recibos-ocr.md](11-recibos-ocr.md).

**Compartilhar para o app** — o app se registra como alvo de compartilhamento para imagem e PDF. Recebeu o comprovante do Pix no WhatsApp? Compartilha para o Finança e ele abre a entrada rápida já com a imagem anexada e o OCR rodando.

**Widget e atalho de sistema** — [12-widgets-e-atalhos.md](12-widgets-e-atalhos.md).

**Texto livre** — previsto para a fase de IA, não no MVP. "gastei 45 no posto" → despesa, R$ 45, Combustível. O parser heurístico (número + preposição + palavra conhecida) já resolveria boa parte sem modelo nenhum, e é o caminho barato a tentar antes de chamar uma API.

## Critérios de aceite

- [ ] Da folha aberta ao salvo em 3 toques, cronometrado
- [ ] Menos de 5 segundos para um usuário que conhece o app
- [ ] Categoria sugerida acerta em pelo menos 60% dos casos depois de 30 lançamentos
- [ ] Funciona idêntico em modo avião
- [ ] Nenhum campo obrigatório além do valor
- [ ] Desfazer funciona até 5 segundos depois
- [ ] Layout íntegro com `fontScale = 2.0`
- [ ] Layout íntegro em tela de 320dp de largura
- [ ] Teclado nunca cobre o botão salvar
