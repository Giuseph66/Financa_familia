# 13 — Relatórios e Comparativo

## Princípio

Relatório existe para responder uma pergunta que a pessoa realmente faz. Gráfico bonito que não responde nada é peso morto. Cada tela aqui nasce de uma pergunta explícita.

| Pergunta real | Tela |
|---|---|
| "Fechei o mês no azul?" | Dashboard |
| "Onde meu dinheiro foi parar?" | Categorias |
| "Como estamos, eu e ela?" | **Comparativo** |
| "Tá melhorando ou piorando?" | Tendência |
| "Quem deve quanto pra quem?" | Acerto |
| "Posso gastar mais esse mês?" | Orçamentos |

## Comparativo entre membros

A tela que justifica o produto existir.

```
┌──────────────────────────────────────┐
│  ◀   Agosto 2026   ▶                 │
├──────────────────────────────────────┤
│  Jesus                               │
│  Entrou  ████████████████  4.200,00  │
│  Saiu    ██████████        2.850,00  │
│  Sobrou                    1.350,00  │
├──────────────────────────────────────┤
│  Maria                               │
│  Entrou  ██████████████    3.640,00  │
│  Saiu    ████████████      3.100,00  │
│  Sobrou                      540,00  │
├──────────────────────────────────────┤
│  Despesas da casa: R$ 2.900,00       │
│  Jesus  1.800  (62%)  ███████        │
│  Maria  1.100  (38%)  ████           │
│                                      │
│  Para dividir igual, Maria           │
│  transfere R$ 350,00                 │
│              [ Registrar acerto ]    │
├──────────────────────────────────────┤
│  Onde cada um mais gastou            │
│  Jesus:  Combustível · Mercado · Bar │
│  Maria:  Mercado · Farmácia · Roupas │
└──────────────────────────────────────┘
```

Decisões que fazem a tela funcionar:

**As barras compartilham a mesma escala.** Cada pessoa com escala própria tornaria a comparação visual mentirosa, que é justamente o oposto do objetivo.

**Só despesas da casa entram no rateio.** O que cada um gasta na conta própria com coisa própria não é da conta do outro. A view `v_member_shared_contribution` já filtra por `accounts.owner_id is null` ou `is_reimbursable`.

**Lançamentos `private` ficam fora, sempre.** É a garantia que torna o compartilhamento aceitável — sem essa porta, a pessoa simplesmente para de registrar o que não quer mostrar, e aí o dado inteiro fica errado.

**O texto nunca julga.** "Maria transfere R$ 350" e não "Maria gastou menos e deve compensar". App de finanças de casal que soa como cobrança vira briga e é desinstalado. O tom é de acerto administrativo, não de placar.

**Divisão igual é o padrão, mas não a única opção.** `household_members.income_share_pct` permite rateio proporcional à renda — quem ganha 70% da renda da casa banca 70% das despesas comuns. Um seletor no topo alterna entre "igual" e "proporcional à renda", e mostra o resultado dos dois.

Se a casa tem um membro só, a tela vira comparação temporal: este mês contra o anterior, mesma estrutura visual.

## Categorias

Rosca com as 8 maiores mais "Outras", e lista abaixo com valor, percentual e variação contra o mês anterior. Toque na categoria abre o detalhe: lançamentos, evolução de 6 meses, média mensal.

Ordenado por valor, decrescente. Ordem alfabética esconde o que importa.

Um detalhe que muda a utilidade: mostrar a **variação contra a média dos últimos 3 meses**, não só contra o mês anterior. Um mês anterior atípico faz a comparação mentir; a média de três suaviza e revela tendência de verdade.

## Tendência

Linha de 12 meses com entradas, saídas e saldo. Média móvel de 3 meses tracejada por cima, porque é ela que mostra a direção.

Marcadores em meses atípicos, com o motivo quando dá para inferir (13º, férias). Um pico de dezembro sem explicação parece erro; rotulado como 13º, vira informação.

## Acerto de contas

Lista de acertos pendentes e histórico. Cada acerto registra período, valor, de quem para quem, e opcionalmente o lançamento de transferência que o quitou.

Registrar um acerto cria opcionalmente duas transações vinculadas (saída na conta de quem paga, entrada na de quem recebe) para que os saldos batam com a realidade.

## Orçamentos

Barra por orçamento, com marcador na linha de alerta. Verde até o alerta, âmbar entre alerta e 100%, vermelho acima.

Mostra também o **ritmo**: "você está no dia 12 de 31 e já usou 58%". Percentual sozinho não diz se está no caminho; ritmo diz. Essa é a diferença entre um número decorativo e um número acionável.

Orçamento com `rollover` mostra a sobra herdada como uma faixa separada na barra.

## Exportação

CSV e PDF, pós-MVP mas previsto no modelo desde já.

CSV com uma linha por lançamento e todas as colunas, separador `;` e codificação UTF-8 com BOM — é o que o Excel brasileiro abre sem embaralhar acento e sem juntar tudo numa coluna. Detalhe pequeno que decide se o arquivo é útil ou lixo.

PDF mensal com resumo, comparativo e lista, para quem gosta de imprimir ou mandar para o contador.

## Implementação dos gráficos

`fl_chart`, com estas regras:

**Cores vêm do design system.** `context.colors.memberPalette` para membros, a cor da própria categoria para categorias. Nunca uma paleta inventada dentro do gráfico.

**Todo gráfico precisa de `Semantics`.** Um gráfico sem descrição textual é invisível para leitor de tela. Descreva o conteúdo: "Gráfico de barras. Jesus: entrou 4.200 reais, saiu 2.850. Maria: entrou 3.640, saiu 3.100."

**Estado vazio é obrigatório.** Zero lançamentos no mês mostra ilustração e "Registre seu primeiro gasto", com botão. Não um gráfico vazio com eixos.

**Animação de entrada de 400ms, uma vez.** Não a cada rebuild — gráfico que reanima ao rolar a tela enjoa rápido.

**Rótulo de valor direto na barra** quando cabe. Obrigar o olho a ir da barra até o eixo e voltar é atrito desnecessário numa tela que se lê em segundos.

## Desempenho

Toda agregação roda em SQL, no SQLite local, nunca em Dart sobre a lista carregada. Carregar 5.000 lançamentos na memória para somar é lento e come RAM sem motivo.

Consultas de relatório usam `customSelect` com `readsFrom` correto — assim continuam reativas e se atualizam sozinhas quando o sync grava.

Para meses fechados (anteriores ao atual), o resultado é imutável e vale um cache em memória com chave `(household, mês, filtros)`, invalidado quando o sync tocar em qualquer transação daquele mês.
