# 14 — Recorrências e Notificações

## Contas fixas

`auto_post = false` é o padrão, e a razão merece ser repetida: lançar automático parece conveniente e envenena os dados. A conta de luz veio R$ 40 mais cara, o app lançou o valor antigo, e o relatório do mês vira ficção. Pior: o usuário confia no número errado.

O padrão é **notificar e deixar confirmar com um toque**, com o valor já preenchido e editável. `auto_post` fica disponível para valor genuinamente fixo — aluguel, assinatura de streaming — e a interface avisa o que isso significa ao ligar.

## Cálculo do próximo vencimento

Onde esse tipo de código costuma errar. Implementado em `core/date/recurrence_calculator.dart`, espelhando `next_due_date()` do Postgres, e coberto por teste.

```dart
DateTime nextDue({
  required DateTime from,
  required Frequency frequency,
  required int interval,
  int? dayOfMonth,
  int? weekday,
}) {
  switch (frequency) {
    case Frequency.weekly:   return from.add(Duration(days: 7 * interval));
    case Frequency.biweekly: return from.add(Duration(days: 14 * interval));
    case Frequency.monthly:
    case Frequency.bimonthly:
    case Frequency.quarterly:
    case Frequency.semiannual:
    case Frequency.yearly:
      final months = frequency.months * interval;
      final target = DateTime(from.year, from.month + months, 1);
      // Dia 31 em mês de 30 dias cai no último dia do mês. Sem este
      // clamp, DateTime(2026, 4, 31) transborda silenciosamente para
      // 1º de maio — e a conta de abril aparece em maio.
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      return DateTime(target.year, target.month,
                      min(dayOfMonth ?? from.day, lastDay));
  }
}
```

Casos que o teste precisa cobrir: dia 31 em fevereiro, 29 de fevereiro em ano bissexto passando para não bissexto, virada de ano, e horário de verão (usar sempre UTC internamente resolve, mas o teste tem que provar).

## Materialização

Um job diário às 8h verifica recorrências vencidas:

```dart
Future<void> materializeDueRecurrences() async {
  final due = await recurrenceDao.dueUntil(DateTime.now());

  for (final r in due) {
    if (r.autoPost) {
      await transactionRepo.create(_fromRecurrence(r, source: 'recurrence'));
      await recurrenceDao.advance(r.id, nextDue(from: r.nextDueOn, ...));
      await notifications.show(
        title: '${r.name} lançado',
        body: '${Money(r.amountCents).formatted} · toque para revisar',
        payload: 'financa://transaction/${tx.id}',
      );
    } else {
      // Não lança. Notifica com ação — o toque abre a entrada rápida
      // preenchida, e o lançamento só existe se a pessoa confirmar.
      await notifications.show(
        title: 'Vence hoje: ${r.name}',
        body: Money(r.amountCents).formatted +
              (r.amountIsEstimate ? ' (estimado)' : ''),
        payload: 'financa://quick-add?recurrence=${r.id}',
        actions: const [
          NotificationAction('confirm', 'Confirmar'),
          NotificationAction('snooze',  'Adiar 3 dias'),
        ],
      );
    }
  }
}
```

**Materialização é idempotente.** O job pode rodar duas vezes no mesmo dia (o WorkManager não garante execução única), e lançar a mesma conta duas vezes é o pior bug possível num app financeiro. A defesa: antes de criar, verificar se já existe transação com aquele `recurrence_id` no período — o índice `transactions_by_recurrence` existe para isso.

Recorrências vencidas há muito tempo (o usuário ficou 3 meses sem abrir o app) **não** geram um lançamento por período em silêncio. Aparece uma tela "6 contas venceram enquanto você esteve fora", com lista e opção de confirmar em lote ou descartar. Encher o extrato de lançamentos que a pessoa não viu acontecer é a forma mais rápida de perder a confiança dela nos números.

## Notificações

| Tipo | Quando | Padrão |
|---|---|---|
| Conta a vencer | `remind_days_before` antes, às 9h | Ligada |
| Conta vencida | No dia seguinte ao vencimento | Ligada |
| Orçamento em alerta | Ao cruzar `alert_pct` | Ligada |
| Orçamento estourado | Ao passar de 100% | Ligada |
| Lançamento de outro membro | Realtime, agrupado | Desligada |
| Lembrete diário | 21h, se não houve lançamento no dia | Desligada |
| Resumo semanal | Domingo, 19h | Desligada |
| Falha de sincronização | Após 24h sem conseguir | Ligada |

As três desligadas por padrão são as que incomodam. Um app que notifica demais é silenciado, e aí as notificações que importam também somem. Ligar é escolha do usuário, em Ajustes › Notificações, com prévia do que cada uma faz.

**Notificação de lançamento de outro membro é agrupada.** "Maria registrou 4 lançamentos" e não quatro notificações. Debounce de 5 minutos.

Nenhuma notificação mostra valor no conteúdo quando o app está com bloqueio biométrico ligado — "Você tem 1 conta vencendo" em vez de "Aluguel R$ 1.800 vence hoje". A notificação aparece na tela de bloqueio, à vista de qualquer um.

## Configuração de background

```dart
await Workmanager().initialize(callbackDispatcher);

await Workmanager().registerPeriodicTask(
  'daily-recurrences', 'materializeRecurrences',
  frequency: const Duration(hours: 12),   // mínimo real do Android é 15min
  initialDelay: _untilNext8am(),
  constraints: Constraints(
    networkType: NetworkType.notRequired,   // recorrência é local
    requiresBatteryNotLow: true,
  ),
  existingWorkPolicy: ExistingWorkPolicy.keep,
);

await Workmanager().registerPeriodicTask(
  'periodic-sync', 'syncData',
  frequency: const Duration(hours: 4),
  constraints: Constraints(networkType: NetworkType.connected),
);
```

**Nem Android nem iOS garantem execução em background.** Fabricantes chineses (Xiaomi, Oppo, Vivo) matam trabalho agendado com agressividade; o iOS decide por heurística de uso. O app não pode depender disso para correção — por isso a materialização também roda toda vez que o app abre. O job em background é otimização de conveniência, e o app fica correto sem ele.

`flutter_local_notifications` precisa de `timezone` inicializado no bootstrap, ou notificação agendada dispara na hora errada para quem não está em UTC:

```dart
tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
```

No Android 13+, permissão de notificação é pedida em runtime. Peça **no momento certo** — quando o usuário cria a primeira conta fixa, explicando por quê — e não no primeiro boot, onde a taxa de negação é muito maior.
