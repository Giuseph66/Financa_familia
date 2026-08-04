# E12 — Relatórios e Comparativo

Referências: [13-relatorios-e-comparativo.md](../13-relatorios-e-comparativo.md)

A etapa que diferencia o produto. O comparativo entre membros é o que este app tem e os outros não.

## Tarefas

### 1. Comparativo

`/reports/comparison`. Layout completo em [13-relatorios-e-comparativo.md](../13-relatorios-e-comparativo.md#comparativo-entre-membros).

Para cada membro: barras de receita e despesa, saldo, percentual de contribuição nas despesas comuns, e as três categorias em que mais gastou.

Quatro decisões que fazem a tela funcionar:

**As barras compartilham a mesma escala.** Escala por pessoa tornaria a comparação visual mentirosa, que é o oposto do objetivo.

**Só despesas da casa entram no rateio.** `v_member_shared_contribution` filtra por conta compartilhada ou `is_reimbursable`. O que cada um gasta na conta própria com coisa própria não é da conta do outro.

**Lançamentos `private` ficam fora, sempre.** É a garantia que torna o compartilhamento aceitável.

**O texto nunca julga.** "Maria transfere R$ 350", não "Maria gastou menos e deve compensar". App de finanças de casal que soa como cobrança vira briga e é desinstalado.

### 2. Rateio proporcional

Seletor entre "dividir igual" e "proporcional à renda", usando `household_members.income_share_pct`.

Mostre o resultado dos dois. Casal com rendas diferentes costuma preferir proporcional, e ver os dois números ajuda a conversa.

### 3. Acerto

Botão "Registrar acerto" cria a linha em `settlements` e, opcionalmente, as duas transações vinculadas (saída de quem paga, entrada de quem recebe) para os saldos baterem com a realidade.

`/reports/settlement`: pendentes e histórico.

### 4. Categorias

`/reports/categories`. Rosca com as 8 maiores mais "Outras", lista abaixo com valor, percentual e variação contra a média de 3 meses.

Ordenado por valor, decrescente. Ordem alfabética esconde o que importa.

Toque abre o detalhe: lançamentos, evolução de 6 meses, média mensal.

### 5. Tendência

`/reports/trends`. Linha de 12 meses com entradas, saídas e saldo, mais a média móvel de 3 meses tracejada — é ela que mostra a direção.

Marcadores em meses atípicos com o motivo quando dá para inferir (13º, férias). Um pico de dezembro sem explicação parece erro.

### 6. Patrimônio

Soma das contas com `include_in_totals`, separando ativos de dívidas de cartão. Evolução de 12 meses.

### 7. Regras dos gráficos

- Cores vêm do design system: `context.colors.memberPalette` para membros, a cor da própria categoria para categorias. Nunca paleta inventada dentro do gráfico.
- **`Semantics` obrigatório.** Gráfico sem descrição textual é invisível para leitor de tela.
- Estado vazio obrigatório, com ilustração e ação.
- Animação de entrada de 400ms, uma vez só — não a cada rebuild.
- Rótulo de valor na barra quando cabe. Obrigar o olho a ir até o eixo e voltar é atrito.

### 8. Desempenho

Agregação em SQL, sempre. Meses fechados são imutáveis e valem cache em memória com chave `(casa, mês, filtros)`, invalidado quando o sync tocar em transação daquele mês.

### 9. Exportação (opcional nesta etapa)

CSV com separador `;` e **UTF-8 com BOM** — é o que o Excel brasileiro abre sem embaralhar acento e sem juntar tudo numa coluna. Detalhe pequeno que decide se o arquivo é útil ou lixo.

## DoD

- [ ] Comparativo mostra todos os membros com a mesma escala
- [ ] Lançamentos `private` não aparecem no comparativo
- [ ] Rateio considera só despesas compartilhadas
- [ ] Alternar igual/proporcional muda o valor do acerto
- [ ] Registrar acerto cria a linha e as transações vinculadas
- [ ] Rosca de categorias com "Outras" agrupando as menores
- [ ] Variação contra média de 3 meses, não contra o mês anterior
- [ ] Tendência com média móvel e marcador de 13º
- [ ] Todo gráfico tem `Semantics` descritivo
- [ ] Todo gráfico tem estado vazio
- [ ] Relatório de 12 meses carrega em menos de 500ms
- [ ] Nenhuma agregação feita em Dart
- [ ] Nenhum texto de julgamento em nenhuma tela

**Marco:** aqui o produto está diferenciado.

Commit: `feat(e12): comparativo entre membros e relatórios`
