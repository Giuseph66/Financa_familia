# E17 — Widgets e Atalhos

Referências: [12-widgets-e-atalhos.md](../12-widgets-e-atalhos.md)

Envolve código nativo. **Flutter não renderiza widget de tela inicial** — o sistema desenha esses widgets fora do processo do app. Kotlin/Glance no Android, Swift/SwiftUI no iOS, obrigatoriamente.

## Tarefas

### 1. Ponte de dados

`lib/features/shortcuts/home_widget_service.dart` conforme [12-widgets-e-atalhos.md](../12-widgets-e-atalhos.md#ponte-de-dados).

Grave valores **já formatados**. O widget nativo não formata moeda nem sabe locale; replicar a formatação em Kotlin e em Swift daria três implementações divergindo.

Chame `refresh()` depois de cada gravação, de cada sync bem-sucedido, e na virada do mês. Widget mostrando saldo do mês passado destrói a confiança no app inteiro.

### 2. Deep links

Registre o esquema `financa://` no `AndroidManifest.xml` e no `Info.plist`. Trate no `go_router` conforme [09-navegacao-e-telas.md](../09-navegacao-e-telas.md#deep-links).

**Deep link nunca executa ação com efeito.** Preenche a tela; o usuário confirma. Qualquer app instalado pode disparar um link desses, e um que gravasse direto seria vetor de injeção de dados.

### 3. Widget Android (Glance)

`android/app/src/main/kotlin/br/com/neurelix/financa/widget/`

Três tamanhos: 2×1 (saldo), 4×1 (4 botões de categoria), 4×2 (saldo + resumo + botões). Código base em [12-widgets-e-atalhos.md](../12-widgets-e-atalhos.md#widget-de-tela-inicial-glance).

`GlanceTheme` segue o Material You do aparelho automaticamente.

`res/xml/balance_widget_info.xml` precisa de `previewLayout`. Sem ela o widget aparece como retângulo cinza no seletor e ninguém adiciona.

### 4. Quick Settings Tile

`QuickAddTileService`. É a resposta prática ao pedido de tela de bloqueio no Android: a barra de status desce por cima do bloqueio.

Atenção ao Android 14+: `startActivityAndCollapse` passou a exigir `PendingIntent`; a sobrecarga com `Intent` lança `IllegalArgumentException`. O código com a verificação de versão está em [12-widgets-e-atalhos.md](../12-widgets-e-atalhos.md#quick-settings-tile).

Mostre o saldo no `subtitle` do tile — informação de graça, sem abrir nada.

### 5. App Shortcuts

Estáticos em `res/xml/shortcuts.xml`: novo gasto, nova receita, foto do recibo.

Dinâmicos via `quick_actions`, com as categorias mais usadas, atualizados junto com o widget.

### 6. Notificação persistente (opcional)

Ligada em Ajustes › Atalhos, **desligada por padrão**. Baixa prioridade, silenciosa, permanente, com botões "Gasto", "Receita" e "Foto".

É o mais perto que Android celular chega de um widget de tela de bloqueio. Desligada por padrão porque notificação permanente incomoda parte dos usuários, e o app não deve presumir.

### 7. Widget iOS (WidgetKit)

Alvo `FinancaWidget` em Xcode. **App Group configurado nos dois alvos** — sem isso os dados não atravessam e o widget aparece vazio, sem erro nenhum, o que torna a depuração desagradável.

Famílias: `systemSmall`, `systemMedium` (tela inicial) e `accessoryCircular`, `accessoryRectangular`, `accessoryInline` (tela de bloqueio).

Os widgets de acessório são **monocromáticos** — o sistema aplica vibrância e cor nenhuma sobrevive. Projete pensando em forma e contraste. Testar só na tela inicial e assumir que o bloqueio fica igual é o erro clássico.

### 8. Control Center (iOS 18+)

`ControlWidget` que abre a entrada rápida. Permite ao usuário substituir a lanterna ou a câmera no botão da tela de bloqueio — o equivalente iOS mais próximo do Quick Settings Tile.

### 9. Siri

`LogExpenseIntent` com AppIntents. "Ei Siri, registrar gasto no Finança" abre a entrada rápida.

Não grava nada no intent: abre o app com o valor preenchido.

### 10. Tela de configuração

Ajustes › Atalhos: escolher as 4 categorias dos botões do widget, ligar a notificação persistente, e instruções de como adicionar o widget em cada plataforma.

A instrução importa. A maioria dos usuários não sabe que o app tem widget se ninguém contar.

### 11. Origem

Lançamento criado por widget grava `source = 'widget'`. Depois de um mês, dá para olhar a distribuição e saber se o investimento valeu.

## DoD

- [ ] Widget Android nos três tamanhos, com preview no seletor
- [ ] Atualiza em até 30s após um lançamento
- [ ] Toque em categoria abre a entrada rápida já com ela selecionada
- [ ] Quick Settings Tile funciona a partir da tela bloqueada
- [ ] Tile mostra o saldo no subtítulo
- [ ] Toque longo no ícone mostra 3 atalhos, nas duas plataformas
- [ ] Widget iOS de tela inicial nos dois tamanhos
- [ ] Widget iOS de bloqueio nas três famílias, legível em monocromático
- [ ] Control Center funcional em iOS 18
- [ ] Siri abre a entrada rápida
- [ ] Compartilhar imagem abre a captura de recibo
- [ ] Widget correto imediatamente após a virada do mês
- [ ] Nenhum ponto de entrada externo grava sem confirmação
- [ ] `source = 'widget'` nos lançamentos vindos de widget

**Marco:** a promessa original está cumprida por inteiro.

Commit: `feat(e17): widgets e atalhos de sistema`
