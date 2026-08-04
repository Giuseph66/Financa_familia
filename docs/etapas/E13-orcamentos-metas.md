# E13 — Orçamentos e Metas

Referências: [02-modelo-de-dados.md](../02-modelo-de-dados.md#planejamento), [13-relatorios-e-comparativo.md](../13-relatorios-e-comparativo.md#orçamentos)

## Tarefas

### 1. Lista de orçamentos

`/more/budgets`. `BudgetBar` por orçamento, com marcador na linha de alerta.

Verde até o `alert_pct`, âmbar entre alerta e 100%, vermelho acima. As três cores também têm ícone diferente — cor nunca é o único sinal.

### 2. Criar orçamento

Categoria (ou geral), escopo (casa ou membro), período, valor, data de início, alerta, rollover.

`scope` permite "a casa gasta no máximo R$ 1.200 em mercado" e "eu gasto no máximo R$ 300 em besteira" convivendo.

Sugira o valor com base na média dos últimos 3 meses daquela categoria. Um campo vazio faz a pessoa chutar; um número ancorado na realidade dela é bem mais útil.

### 3. Ritmo

Além do percentual, mostre o ritmo: **"dia 12 de 31, você usou 58%"**.

Percentual sozinho não diz se está no caminho; ritmo diz. É a diferença entre um número decorativo e um número acionável.

Quando está acima do ritmo, mostre a projeção: "nesse passo, fecha em R$ 1.480 de R$ 1.200".

### 4. Rollover

Orçamento com `rollover = true` herda a sobra do período anterior. A barra mostra a sobra herdada como uma faixa separada, para o usuário entender de onde veio o valor a mais.

### 5. Alertas

Notificação ao cruzar `alert_pct` e ao passar de 100%. Uma vez por período, não a cada lançamento.

Verificação após cada gravação e no job diário.

### 6. Metas

`/more/goals`. Cartão por meta com anel de progresso, valor atual, alvo, prazo e quanto falta por mês para chegar.

"Faltam R$ 3.200 em 8 meses = R$ 400/mês" é o número que a pessoa usa para decidir. Mostrar só a barra de progresso é bonito e inútil.

### 7. Contribuições

Adicionar contribuição, opcionalmente vinculada a uma transferência real para a conta da meta.

Progresso é `SUM(goal_contributions)`. Não existe coluna `current_cents` — pelo mesmo motivo de saldo de conta.

Contribuição negativa é resgate, permitida e visível no histórico.

### 8. Meta concluída

Ao atingir o alvo: animação de celebração (uma vez), e a meta vai para "Concluídas". Não some — ver o que já foi conquistado é o que sustenta o hábito.

## DoD

- [ ] CRUD de orçamento nos dois escopos e nos três períodos
- [ ] Barra com as cores e o marcador corretos
- [ ] Ritmo calculado certo em qualquer dia do mês
- [ ] Projeção aparece quando acima do ritmo
- [ ] Rollover herda a sobra e mostra a faixa separada
- [ ] Alerta dispara uma vez por período, não a cada lançamento
- [ ] Sugestão de valor baseada na média de 3 meses
- [ ] CRUD de meta com progresso calculado por soma
- [ ] "Quanto falta por mês" correto
- [ ] Contribuição negativa funciona como resgate
- [ ] Meta concluída celebra e vai para o histórico
- [ ] Tudo offline e sincronizando

Commit: `feat(e13): orçamentos e metas`
