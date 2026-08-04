# E07 — Casa e Membros

Referências: [02-modelo-de-dados.md](../02-modelo-de-dados.md#identidade-e-grupo), [09-navegacao-e-telas.md](../09-navegacao-e-telas.md)

## Tarefas

### 1. Onboarding

Três passos, menos de 60 segundos, tudo pulável:

1. **Nome da casa** — pré-preenchido com "Minhas finanças" (o trigger já criou). Pode virar "Casa" ou o nome da família.
2. **Primeira conta** — nome, tipo, saldo atual. O saldo vira `opening_balance_cents`.
3. **Convidar alguém** — gera o código e oferece compartilhar. Pulável, e a maioria vai pular no primeiro acesso.

Marca `profiles.onboarded_at` ao concluir ou pular.

### 2. Seletor de casa

Um usuário pode pertencer a várias (a pessoal e a da família). Seletor no topo do dashboard, com a ativa persistida em `app_settings`.

Trocar de casa **exige um pull completo** dos dados da nova. Mostre progresso; não deixe a tela em branco.

### 3. Membros

`/more/household/members`. Lista com avatar, nome, papel, cor e o total gasto no mês. Ações: editar (nome, cor, emoji), mudar papel (só `owner`), remover (só `owner`).

Remover é soft delete no membro. **Os lançamentos dele permanecem** — apagar histórico financeiro porque alguém saiu do grupo destrói o passado. A UI mostra "Maria (removida)" nos lançamentos antigos.

### 4. Membro-fantasma

Botão "Adicionar sem convite". Cria `household_members` com `user_id = null`.

Serve para um filho pequeno ou alguém sem smartphone: existe como membro, recebe gastos atribuídos, aparece no comparativo. Depois pode ser convertido em usuário real preenchendo `user_id`, sem perder nada do histórico. É um campo no schema e evita uma migração dolorosa lá na frente.

### 5. Convites

`/more/household/invite`:

```dart
final code = await supabase.rpc('create_invite', params: {
  'p_household': householdId,
  'p_role': 'adult',
  'p_days': 7,
});
```

Mostre o código em fonte grande e monoespaçada, com botão de copiar e de compartilhar. O texto compartilhado inclui o deep link:

```
Entre na nossa casa no Finança!
Código: ABCD2345
financa://join?code=ABCD2345
```

Lista de convites ativos com opção de revogar.

### 6. Aceitar convite

`/join`, acessível deslogado (redireciona para login e volta) e por deep link.

```dart
final householdId = await supabase.rpc('redeem_invite', params: {'p_code': code});
```

Traduza os erros: convite expirado, já usado, inválido. Depois de aceitar, faz o pull completo da nova casa.

### 7. Papéis na interface

A RLS já bloqueia no servidor. A UI **também** precisa refletir, para não oferecer o que vai falhar:

| Papel | Interface |
|---|---|
| `owner` | Tudo |
| `adult` | Sem gerência de membros nem exclusão da casa |
| `teen` | Só os próprios lançamentos; sem holerite, sem contas de outros, sem orçamento da casa |
| `viewer` | Sem nenhum botão de escrita |

Botão que a RLS rejeitaria não deve existir na tela. Deixar visível e falhar depois é pior que esconder.

### 8. Ajustes da casa

Nome, ícone, cor, moeda e `month_start_day`.

`month_start_day` merece explicação na tela: "Seu mês financeiro começa no dia X". Quem recebe dia 5 pensa o mês de 5 a 4, e essa opção faz todo o resto do app respeitar isso.

## DoD

- [ ] Onboarding completo em menos de 60s, com todos os passos puláveis
- [ ] Criar segunda casa e alternar entre elas funciona
- [ ] Código de convite gerado, compartilhado e aceito em outro aparelho
- [ ] Deep link `financa://join?code=...` funciona
- [ ] Convite expirado mostra mensagem clara
- [ ] Aceitar o mesmo convite duas vezes não duplica membro
- [ ] Membro-fantasma criado, com gastos atribuídos, aparecendo no comparativo
- [ ] Converter fantasma em usuário real preserva o histórico
- [ ] `teen` não vê botão de holerite nem de orçamento da casa
- [ ] `viewer` não vê nenhum botão de escrita
- [ ] Remover membro preserva os lançamentos dele
- [ ] Tentar remover o último `owner` mostra erro
- [ ] `month_start_day` altera o período no dashboard

Commit: `feat(e07): casa, membros e convites`
