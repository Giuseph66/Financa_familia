# E15 — Holerite

Referências: [15-holerite.md](../15-holerite.md)

Feito para a realidade CLT brasileira: insalubridade, adicionais, DSR, INSS, IRRF. Nenhum app internacional modela isso.

**É opcional.** Se virar caminho obrigatório, contradiz o princípio número um do app e estraga o produto.

## Tarefas

### 1. Lista

`/more/payslips`. Agrupada por membro e ano. Cada item: mês, empregador, líquido, e o tipo quando não é mensal.

Filtro por membro. Respeita a RLS: `teen` e `viewer` não veem esta tela, e ela nem aparece no menu para eles.

### 2. Formulário

Layout em [15-holerite.md](../15-holerite.md#fluxo). Cabeçalho com membro, competência, tipo e empregador. Duas seções, proventos e descontos, cada uma com botão de adicionar rubrica. Totais no rodapé, calculados.

Totais **nunca são digitados**. São recalculados a cada mudança, local e no servidor pelo trigger.

Se o líquido não bate com o que caiu na conta, ou falta rubrica ou tem valor errado — e o app aponta isso, comparando com o lançamento vinculado.

### 3. Rubricas

Catálogo em [../anexos/seed-rubricas.md](../anexos/seed-rubricas.md). Sugestões, não lista fechada — o usuário digita o que quiser.

O seletor mostra primeiro as rubricas que **aquele membro** já usou, ordenadas por frequência. Não uma lista de 40 em ordem alfabética.

Campo `reference` para "20%", "12h", "5 dias" — é o que está no papel e ajuda a conferir.

### 4. Copiar do mês anterior

O atalho que faz a feature ser usada. Traz todas as rubricas com os valores antigos; o usuário ajusta só o que mudou, tipicamente horas extras e IRRF.

De 8 campos para 2. Sem isso, digitar 8 rubricas por mês é atrito que mata a funcionalidade.

### 5. Lançar o líquido

Checkbox "Lançar como receita" com seletor de conta. Cria a transação de receita e vincula em `payslips.transaction_id`.

Uma tela, dois registros coerentes.

### 6. Foto do contracheque

Reusa o fluxo de [E16](E16-recibos.md), com parser diferente: procura pares "descrição … valor" em colunas e as palavras-chave conhecidas.

Acerto menor que o do cupom fiscal (layout varia muito entre empresas), mas preencher metade das linhas já vale. O usuário confere e corrige.

Depende de E16; se estiver executando fora de ordem, deixe esta tarefa para depois.

### 7. Relatórios de renda

`/more/payslips/reports`:

- **Evolução** — linha de 12 meses do bruto e do líquido, com 13º e férias destacados. Toggle para excluir não-mensais e ver a linha de base real.
- **Composição** — quanto do bruto é fixo e quanto é variável. Quem tem 30% da renda em horas extras está numa situação bem diferente de quem tem tudo fixo.
- **Carga de descontos** — percentual do bruto que vai embora, e em quê. Muita gente não sabe que perde 25%.

### 8. Alimentar o rateio

Média do líquido dos últimos 3 meses preenche `household_members.income_share_pct`, que alimenta o rateio proporcional de [E12](E12-relatorios.md).

Botão "Atualizar percentuais a partir dos holerites", não automático — mudar a proporção do rateio sem avisar é o tipo de coisa que gera desconfiança.

## DoD

- [ ] CRUD de holerite com rubricas
- [ ] Totais recalculados, nunca digitados
- [ ] `teen` e `viewer` não veem a tela nem o item de menu
- [ ] Copiar do mês anterior traz todas as rubricas
- [ ] Seletor mostra as rubricas frequentes do membro primeiro
- [ ] Lançar o líquido cria a receita vinculada
- [ ] Divergência entre líquido e lançamento é sinalizada
- [ ] 13º e férias separados na evolução de renda
- [ ] Toggle de excluir não-mensais funciona
- [ ] Carga de descontos correta
- [ ] Atualizar percentuais muda o rateio em E12
- [ ] Nada do holerite aparece em notificação ou widget

Commit: `feat(e15): holerite detalhado`
