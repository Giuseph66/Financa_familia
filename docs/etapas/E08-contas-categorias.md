# E08 — Contas e Categorias

Referências: [02-modelo-de-dados.md](../02-modelo-de-dados.md#contas-e-categorias)

## Tarefas

### 1. Lista de contas

`/accounts`. Agrupada por tipo, com saldo em cada uma e o total no topo. Contas arquivadas numa seção recolhida no fim.

Cartão de crédito mostra **fatura atual e limite disponível**, não "saldo". Saldo de cartão é dívida, e chamar de saldo confunde: o número negativo grande assusta quem não esperava.

### 2. Criar e editar conta

Formulário: nome, tipo, instituição, cor, ícone, saldo inicial, dono (você / a casa / outro membro), visibilidade.

Campos que só aparecem para `credit_card`: limite, dia de fechamento, dia de vencimento. Fechamento é obrigatório — sem ele não dá para montar fatura, e a constraint no banco rejeita.

`benefit` (vale-alimentação) merece uma explicação curta na tela: saldo de VR não é dinheiro livre, e por isso `include_in_totals` vem desmarcado por padrão nesse tipo.

### 3. Saldos

`v_account_balances` no servidor, `TransactionDao.watchBalances` no local. Sempre calculado: `opening_balance_cents + SUM(signed_amount_cents)`.

Nunca crie um campo `balance`. É a fonte número um de divergência entre dispositivos, e a razão de o modelo ter sido desenhado assim.

Mostre também o **saldo projetado**, que inclui lançamentos `pending` — é o "quanto vai sobrar se tudo que está no ar acontecer".

### 4. Detalhe da conta

Saldo, gráfico de evolução de 30 dias, e o extrato filtrado por ela. Ações: editar, arquivar, transferir.

Arquivar em vez de apagar: o histórico continua correto, a conta some das listas de seleção.

### 5. Fatura de cartão

Para conta `credit_card`, uma aba de faturas. Agrupa por ciclo com `statement_closing_day`, conforme `v_credit_card_bill`.

Mostra o ciclo atual, o total, quanto é de parcelas de meses anteriores, e a data de vencimento. "Pagar fatura" cria uma transferência da conta corrente para o cartão.

O detalhe que confunde quem nunca implementou: uma compra em 28/01 num cartão que fecha dia 25 pertence à fatura de **fevereiro**. A view já faz essa conta.

### 6. Categorias

`/more/categories`. Árvore de dois níveis, arrastável para reordenar, separada em Despesas e Receitas.

Criar, editar (nome, ícone, cor, pai), arquivar. Categoria com `is_system = true` pode ser renomeada mas não apagada — só arquivada.

Seletor de ícone com um conjunto curado de ~80 ícones Material, agrupados por tema. Uma lista de 2.000 ícones é pior que 80 bem escolhidos.

### 7. Estabelecimentos

`/more/merchants`, uma tela simples de manutenção: lista com contagem de uso e a categoria padrão, editável.

Esta é a **camada zero de inteligência do app** e não usa IA nenhuma. É o que faz a sugestão de categoria acertar sozinha depois de algumas semanas de uso. Vale a tela para o usuário poder corrigir um aprendizado errado.

### 8. Mesclar estabelecimentos

"Carrefour" e "CARREFOUR SA" viram dois registros quando vêm de fontes diferentes (digitado vs OCR). Botão de mesclar: reaponta os lançamentos e apaga o duplicado.

Sem isso a sugestão degrada com o tempo, porque o histórico se fragmenta entre variações do mesmo nome.

## DoD

- [ ] CRUD de conta funcionando para todos os 7 tipos
- [ ] Saldo confere com a soma manual dos lançamentos
- [ ] Saldo projetado inclui `pending`, saldo normal não
- [ ] Cartão mostra fatura e limite, não "saldo"
- [ ] Compra depois do fechamento entra na fatura seguinte
- [ ] Conta arquivada some das listas mas mantém o histórico
- [ ] CRUD de categoria com hierarquia de dois níveis
- [ ] Criar subcategoria de subcategoria é rejeitado
- [ ] Categoria de sistema não pode ser apagada, só arquivada
- [ ] Reordenar categorias persiste
- [ ] Mesclar estabelecimentos reaponta os lançamentos
- [ ] Tudo funciona offline e sincroniza depois

Commit: `feat(e08): contas, categorias e estabelecimentos`
