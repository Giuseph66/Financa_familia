# E10 — Lançamentos

Referências: [09-navegacao-e-telas.md](../09-navegacao-e-telas.md#extrato-transactions), [02-modelo-de-dados.md](../02-modelo-de-dados.md#lançamentos)

## Tarefas

### 1. Extrato

`/transactions`. Lista agrupada por dia, cabeçalho pegajoso com data e total do dia. Rolagem infinita em páginas de 50.

Cada item: ícone da categoria com a cor dela, descrição (ou o nome da categoria, se vazia), o membro em texto pequeno quando a casa tem mais de um, valor à direita com sinal e cor. Clipe se tem recibo; nuvem cortada se ainda não sincronizou.

### 2. Gestos

Deslizar para a esquerda apaga, com desfazer. Para a direita, duplica.

Duplicar existe porque gasto repetido é comum — o mesmo café, a mesma passagem — e duplicar é mais rápido que digitar de novo. Abre a entrada rápida preenchida com a data de hoje.

### 3. Filtros

Barra com mês, membro, conta, categoria, tipo e busca por texto.

**Filtro ativo vira chip visível**, removível com um toque. Filtro invisível é a causa clássica de "sumiram meus lançamentos" — o usuário filtrou por engano, esqueceu, e conclui que o app perdeu dados.

Filtros persistem na sessão, não entre execuções.

### 4. Busca

Por descrição, estabelecimento, observação, etiqueta e valor. Debounce de 300ms. Busca por valor aceita "45" e "45,90".

### 5. Detalhe

`/transactions/:id`. Valor grande no topo com a cor do tipo. Campos em lista **editável inline**: toque no campo, muda, salva sozinho.

Sem botão "Editar" que troca a tela de modo — dois modos numa tela de detalhe é atrito puro.

Se for parcelado, mostra "3 de 12" com link para as outras. Se for transferência, mostra as duas contas e edita as duas pernas juntas.

### 6. Transferência

Formulário: origem, destino, valor, data, descrição. Usa o RPC `create_transfer`, que grava as duas pernas atomicamente.

Fazer isso em duas chamadas do cliente permitiria um estado em que saiu de uma conta e não entrou na outra.

Origem e destino iguais é rejeitado. Editar ou apagar uma perna afeta as duas.

### 7. Parcelamento

Na entrada rápida, em "Mais detalhes": "Parcelar em N vezes".

Gera **N lançamentos**, um por mês, com o mesmo `installment_group_id`. Não um lançamento com o valor cheio — é assim que a fatura funciona de verdade, e é a única forma de o mês futuro mostrar o comprometimento correto.

O resto da divisão vai na primeira parcela: R$ 100 em 3x é 33,34 + 33,33 + 33,33. Somar de volta tem que dar exatamente 10000 centavos.

Apagar uma parcela pergunta: só esta, ou todas as futuras.

### 8. Divisão (splits)

Em "Mais detalhes", "Dividir". Dois usos, o mesmo mecanismo:

- **entre categorias** — R$ 250 no mercado sendo R$ 200 de comida e R$ 50 de limpeza;
- **entre membros** — rateio de uma despesa comum.

A UI **não deixa salvar desbalanceado**: mostra quanto falta ou sobra em tempo real. O banco não valida isso por trigger de propósito (quebraria o sync); a garantia é aqui e na view de diagnóstico.

Atalhos "dividir igualmente" e "dividir proporcional à renda".

### 9. Ações em lote

Seleção múltipla por toque longo. Ações: mudar categoria, mudar membro, apagar, marcar como conciliado.

Serve para arrumar histórico bagunçado, que é o que acontece depois de alguns meses de uso apressado.

### 10. Diagnóstico

Ajustes › Diagnóstico, alimentado por `v_split_integrity`: lançamentos cujos splits não fecham. Em operação normal vem vazia. Se vier linha, houve bug de escrita ou conflito mal resolvido — e é melhor ter onde olhar.

## DoD

- [ ] Extrato carrega 1.000 lançamentos com rolagem fluida
- [ ] Agrupamento por dia com total correto
- [ ] Deslizar apaga com desfazer; deslizar duplica
- [ ] Filtro aplicado sempre visível como chip
- [ ] Busca por texto e por valor funciona
- [ ] Edição inline salva sem botão de confirmar
- [ ] Transferência cria duas pernas atomicamente
- [ ] Transferência não aparece como despesa nem como receita no relatório
- [ ] Transferência move o saldo das duas contas
- [ ] Parcelamento em 3x gera 3 lançamentos que somam exato
- [ ] Apagar parcela oferece "só esta" e "todas as futuras"
- [ ] Split não salva desbalanceado
- [ ] Ações em lote funcionam
- [ ] `v_split_integrity` vazia após uso normal

Commit: `feat(e10): extrato, transferências, parcelas e divisões`
