# E11 — Dashboard

Referências: [09-navegacao-e-telas.md](../09-navegacao-e-telas.md#dashboard-)

A ordem vertical das seções **é** a mensagem do produto. Não reordene.

## Tarefas

### 1. Navegador de mês

Setas e o nome do mês. Deslizar horizontalmente troca.

Respeita `households.month_start_day`: se a casa fecha o mês no dia 5, "Agosto" vai de 5 de agosto a 4 de setembro, e o rótulo diz isso quando o dia não é 1.

### 2. Saldo do mês

Número grande, tipografia `displayLarge` com dígitos tabulares. Entradas menos saídas do período.

Toque alterna o **modo privacidade**: todos os valores do app viram `R$ ••••`. Serve para abrir no ônibus sem exibir o salário para quem está ao lado. Estado global, não por tela.

Cor pelo sinal, com o sinal também em texto — cor nunca é o único indicador.

### 3. Entradas e saídas

Dois `StatTile` lado a lado, com variação percentual contra a **média dos últimos 3 meses**, não contra o mês anterior. Um mês anterior atípico faz a comparação mentir.

### 4. Comparativo dos membros

Barras horizontais, uma por pessoa, na cor do membro. Toque leva ao relatório completo.

**Esta seção vem antes de qualquer gráfico genérico**, porque é o que define o produto.

Se a casa tem um membro só, vira "Você × mês passado" — mesma estrutura visual, sem espaço vazio e sem comparativo consigo mesmo em barras.

### 5. Orçamentos em risco

Só os que passaram do `alert_pct`. Se nenhum, **a seção não existe** — não mostre "tudo certo" ocupando espaço.

### 6. Próximas contas

Próximos 7 dias, de `v_upcoming_bills`. Cada uma com botão "Pagar" que lança com um toque, já preenchido.

Vencidas aparecem primeiro, destacadas.

### 7. Últimos lançamentos

Cinco, com link para o extrato. Reusa `TransactionTile`.

### 8. Contas e saldos

Carrossel horizontal de `AccountCard`. Cartão de crédito mostra fatura e limite.

### 9. Estados

- **Casa nova, zero lançamentos** — ilustração e "Registre seu primeiro gasto", com botão. Não um dashboard de zeros.
- **Carregando** — skeleton com a forma final, nunca spinner centralizado.
- **Offline** — faixa fina no topo, discreta, não bloqueante.
- **Sincronizando** — barra de 2dp sob a AppBar.

### 10. Puxar para atualizar

Dispara `sync(force: true)`. É o gesto que todo mundo tenta; se não fizer nada, o app parece quebrado.

### 11. Desempenho

Toda agregação em SQL, no SQLite. Nunca carregar a lista em Dart para somar.

Meta: abrir em menos de 300ms com 5.000 lançamentos no banco. Se passar disso, o problema é índice faltando ou agregação em Dart.

## DoD

- [ ] Todas as seções na ordem especificada
- [ ] Saldo confere com a soma manual
- [ ] Modo privacidade esconde todos os valores do app
- [ ] Comparativo aparece com 2+ membros; vira temporal com 1
- [ ] Seção de orçamento some quando nenhum está em risco
- [ ] "Pagar" na conta a vencer lança com um toque
- [ ] Estado vazio com ilustração e ação
- [ ] Skeleton no carregamento, não spinner
- [ ] Puxar para atualizar sincroniza
- [ ] Abre em menos de 300ms com 5.000 lançamentos
- [ ] Deslizar troca o mês
- [ ] `month_start_day` diferente de 1 muda o período corretamente

Commit: `feat(e11): dashboard`
