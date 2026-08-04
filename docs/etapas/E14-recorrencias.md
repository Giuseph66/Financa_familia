# E14 — Recorrências e Notificações

Referências: [14-recorrencias-e-notificacoes.md](../14-recorrencias-e-notificacoes.md)

## Tarefas

### 1. Calculadora de vencimento

`lib/core/date/recurrence_calculator.dart`, espelhando `next_due_date()` do Postgres.

**Escreva os testes primeiro.** É onde esse tipo de código erra: dia 31 em mês de 30 dias, 31 em fevereiro, 29/02 de bissexto para não bissexto, virada de ano.

O clamp para o último dia do mês é obrigatório. Sem ele, `DateTime(2026, 4, 31)` transborda silenciosamente para 1º de maio, e a conta de abril aparece em maio.

### 2. CRUD de recorrência

`/more/recurrences`. Nome, tipo, valor, "valor estimado", conta, categoria, membro, frequência, intervalo, dia, data de início, data de fim, lançamento automático, dias de aviso.

`auto_post` **desligado por padrão**, com explicação ao ligar. Lançar automático parece conveniente e envenena os dados: a conta de luz veio R$ 40 mais cara, o app lançou o valor antigo, e o relatório vira ficção.

`amount_is_estimate` faz a UI mostrar "~R$ 180" em vez de "R$ 180", que é honesto para conta de luz.

### 3. Lista

Agrupada por status: vencidas, esta semana, este mês, futuras, pausadas. Cada uma com valor, data e conta.

Total mensal comprometido no topo: "R$ 2.840 em contas fixas". É o número que a pessoa quer saber e quase nenhum app mostra.

### 4. Materialização

Job que verifica vencidas e:

- `auto_post = true` → cria o lançamento e notifica que foi criado
- `auto_post = false` → notifica com ações "Confirmar" e "Adiar 3 dias"

**Idempotente.** O WorkManager não garante execução única, e lançar a mesma conta duas vezes é o pior bug possível num app financeiro. Antes de criar, verifique se já existe transação com aquele `recurrence_id` no período — o índice `transactions_by_recurrence` existe para isso.

Roda no job em background **e** toda vez que o app abre. O background não é confiável e o app precisa estar correto sem ele.

### 5. Contas acumuladas

Se o usuário ficou 3 meses sem abrir, **não** gere um lançamento por período em silêncio.

Tela "6 contas venceram enquanto você esteve fora", com lista e opção de confirmar em lote ou descartar. Encher o extrato de lançamentos que a pessoa não viu acontecer é a forma mais rápida de perder a confiança dela nos números.

### 6. Notificações

Configure `flutter_local_notifications` com `timezone` inicializado no bootstrap, ou notificação agendada dispara na hora errada.

Canais: contas, orçamentos, família, sistema.

A tabela de tipos e padrões está em [14-recorrencias-e-notificacoes.md](../14-recorrencias-e-notificacoes.md#notificações). Três ficam desligadas por padrão porque são as que incomodam — app que notifica demais é silenciado, e aí as que importam somem junto.

**Nenhuma notificação mostra valor quando o bloqueio biométrico está ligado.** "Você tem 1 conta vencendo", não "Aluguel R$ 1.800 vence hoje". A notificação aparece na tela de bloqueio, à vista de qualquer um.

### 7. Permissão de notificação

Android 13+ pede em runtime. Peça **no momento certo** — quando o usuário cria a primeira conta fixa, explicando por quê — e não no primeiro boot, onde a taxa de negação é muito maior.

### 8. Background

`workmanager` conforme [14-recorrencias-e-notificacoes.md](../14-recorrencias-e-notificacoes.md#configuração-de-background). Dois jobs: materialização a cada 12h e sync a cada 4h.

## DoD

- [ ] Testes da calculadora passando, inclusive os quatro casos de borda
- [ ] CRUD de recorrência em todas as frequências
- [ ] `auto_post` desligado por padrão, com explicação ao ligar
- [ ] Valor estimado exibido com "~"
- [ ] Total mensal comprometido correto
- [ ] Materialização idempotente: rodar duas vezes não duplica
- [ ] Contas acumuladas mostram tela de revisão, não lançam sozinhas
- [ ] Notificação de vencimento chega no dia certo, no horário certo
- [ ] Ação "Confirmar" da notificação lança sem abrir o app inteiro
- [ ] Notificação não mostra valor com biometria ligada
- [ ] Permissão pedida no momento contextual
- [ ] Job em background funciona com o app fechado
- [ ] Materialização também roda ao abrir o app

Commit: `feat(e14): recorrências e notificações`
