# E09 — Entrada Rápida

Referências: [10-entrada-rapida.md](../10-entrada-rapida.md)

**A etapa mais importante do produto.** Se esta tela for lenta, nada mais importa: o usuário para de registrar e o app morre.

Meta com número, verificada em teste: **3 toques, menos de 5 segundos.**

## Tarefas

### 1. `AmountInput`

Teclado numérico próprio, não `TextField` com `keyboardType: number`.

O teclado do sistema demora a subir, muda de layout entre aparelhos e traz teclas inúteis. O nosso tem tecla `00` (economiza dois toques em valor redondo), teclas de 64dp de altura e resposta tátil.

Valor sempre em centavos, montado da direita para a esquerda: digitar 3, 2, 9, 0 produz `3290`. **Nunca existe estado inválido** e não há parsing de string para double em lugar nenhum.

Teto de R$ 999.999.999,99.

### 2. `CategoryGrid`

Duas linhas de 5. As 6 primeiras são as favoritas, calculadas por:

```
score = usos_ultimos_60d * (1 / (1 + dias_desde_ultimo_uso))
```

Frequência sozinha congela o grid nas categorias do primeiro mês; recência sozinha oscila demais. O produto das duas adapta sem tremer.

Categorias fixadas pelo usuário vêm primeiro e não saem. O `+` abre a lista completa.

### 3. A folha

`/quick-add`, folha modal cobrindo cerca de 90% da tela. Layout de [10-entrada-rapida.md](../10-entrada-rapida.md#o-fluxo).

De cima para baixo: segmentado de tipo, valor grande, grid de categorias, chips de conta/data/membro, teclado, botão salvar.

**Sem campo de descrição visível.** Ele existe atrás de "Mais detalhes". Campo de texto visível é convite psicológico a preenchê-lo, e é exatamente o atrito a eliminar.

### 4. Padrões inteligentes

Implemente `suggestCategory` de [10-entrada-rapida.md](../10-entrada-rapida.md#padrões-inteligentes), com as três camadas em ordem: estabelecimento conhecido → faixa de horário → mais usada em 30 dias.

Conta padrão: a última usada naquele tipo de lançamento. Data: hoje, com "ontem" ao lado depois das 22h. Membro: você.

### 5. Salvar

`id` gerado no cliente com UUID v7. Grava no Drift e enfileira na outbox, na mesma transação. Sync com debounce de 3s. Feedback tátil. Atualiza o widget.

### 6. Aprendizado

Depois de salvar, se houve estabelecimento: cria ou incrementa em `merchants`, e fixa a categoria escolhida como `default_category_id`.

É isto que faz a sugestão melhorar sozinha com o uso, sem modelo nenhum.

### 7. Pós-salvar

Barra de 5 segundos:

```
✓ R$ 32,90 · Mercado          [Desfazer]  [+ Outro]
```

**Desfazer** — soft delete imediato, sem confirmação. Muito mais barato que um diálogo "tem certeza?" em toda gravação, e cobre melhor o erro real.

**+ Outro** — reabre mantendo conta, data e membro, zerando o valor. Registrar cinco itens da feira vira uma sequência fluida.

### 8. Mais detalhes

Expansível com: descrição, estabelecimento (com autocomplete), forma de pagamento, observação, etiquetas, visibilidade, marcar como reembolsável, anexar foto.

### 9. Pré-preenchimento por deep link

`/quick-add` aceita `kind`, `category`, `amount`, `account`, `recurrence`. Usado pelos widgets, atalhos e notificações.

**Deep link nunca grava.** Preenche a tela; o usuário confirma. Qualquer app instalado pode disparar um link desses.

### 10. Testes

O teste de integração cronometrado de [17-testes.md](../17-testes.md#teste-de-integração-da-entrada-rápida). É o que mede a promessa central do produto.

## DoD

- [ ] Registrar despesa em exatamente 3 toques
- [ ] Menos de 5s no teste de integração cronometrado
- [ ] Funciona idêntico em modo avião
- [ ] Categoria sugerida acerta em ≥60% depois de 30 lançamentos
- [ ] Nenhum campo obrigatório além do valor
- [ ] Desfazer funciona nos 5 segundos
- [ ] "+ Outro" mantém conta, data e membro
- [ ] Estabelecimento novo é criado e aprende a categoria
- [ ] Layout íntegro com `fontScale = 2.0`
- [ ] Layout íntegro em tela de 320dp
- [ ] Teclado nunca cobre o botão salvar
- [ ] Deep link pré-preenche sem gravar

**Marco:** aqui o app é usável. Instale no celular e comece a usar de verdade. O feedback de uso real vale mais que as próximas nove etapas planejadas no vácuo.

Commit: `feat(e09): entrada rápida em 3 toques`
