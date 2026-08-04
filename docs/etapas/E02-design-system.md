# E02 — Design System

Referências: [08-design-system.md](../08-design-system.md)

Vem antes das features de propósito. Construir telas primeiro e "extrair o design system depois" nunca acontece — o que acontece é `Color(0xFF...)` espalhado por 40 arquivos e um tema que não troca.

## Tarefas

### 1. Fonte

Baixe Inter Variable e coloque em `assets/fonts/`. Declare no `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Variable.ttf
```

Embarcada, não do Google Fonts em runtime: o app funciona offline, e baixar fonte no primeiro boot causa um salto visual.

### 2. Tokens

`lib/design_system/tokens/`:

- `spacing.dart` — escala de 4pt com nomes
- `radii.dart` — raios e `BorderRadius` prontos
- `motion.dart` — durações e curvas, teto de 400ms
- `typography.dart` — **com `FontFeature.tabularFigures()` nos estilos de valor**
- `app_colors.dart` — `ThemeExtension` com o vocabulário financeiro
- `app_shapes.dart` — `ThemeExtension` para o `CornerStyle`

Os dígitos tabulares não são detalhe estético: sem eles a coluna de valores fica em serra, porque o "1" é mais estreito que o "8".

### 3. Tema

`lib/design_system/theme/`:

- `theme_preset.dart` — o modelo Freezed com os 6 presets
- `app_theme.dart` — `buildTheme(preset, brightness, dynamicScheme)`
- `theme_controller.dart` — Riverpod, persistindo em `app_settings`
- `context_extensions.dart` — `context.colors`, `context.text`, `context.l10n`

### 4. Componentes

Na ordem, porque os de baixo dependem dos de cima:

**Átomos** — `MoneyText`, `AppIcon`, `AppChip`, `AppDivider`, `AppAvatar`, `Skeleton`, `AppBadge`, `SignedIcon`

**Moléculas** — `AppButton` (5 variantes), `AppTextField`, `CategoryChip`, `CategoryGrid`, `AccountChip`, `MemberChip`, `DateChip`, `AppCard`, `StatTile`, `ProgressBar`, `BudgetBar`, `EmptyState`, `SegmentedToggle`, `FilterBar`

**Organismos** — `AppScaffold`, `AppBottomNav`, `TransactionTile`, `MonthNavigator`

`AmountInput` e os gráficos ficam para as etapas que os usam — construir sem o consumidor concreto produz API errada.

`MoneyText` primeiro. É o componente mais usado do app e o que centraliza a decisão "como dinheiro aparece aqui".

### 5. Galeria

`lib/design_system/gallery/gallery_screen.dart`, rota `/dev/ds`, só com `Env.isDev`.

Lista todo componente em todo estado, com controles ao vivo: trocar preset, alternar claro/escuro, escala de fonte, densidade, modo daltônico.

Não é enfeite — é onde se descobre que o botão destrutivo some no escuro. Adicionar entrada na galeria é parte do DoD de todo componente novo, daqui em diante.

### 6. Golden tests

Para os componentes mais visuais, nos dois temas e em duas escalas de fonte. Ver [17-testes.md](../17-testes.md#golden-tests).

## DoD

- [ ] `/dev/ds` abre e lista todos os componentes
- [ ] Trocar preset muda o app inteiro; nenhum componente fica com a cor antiga
- [ ] Alternar claro/escuro sem nenhum texto ilegível
- [ ] `fontScale = 2.0` sem overflow em nenhum componente
- [ ] Modo daltônico troca verde/vermelho por azul/laranja
- [ ] `MoneyText` alinha uma coluna de valores de larguras diferentes
- [ ] `grep -rn "Color(0xFF" lib/features/ lib/app/` sem resultado
- [ ] `grep -rn "EdgeInsets.all([0-9]" lib/features/` sem resultado
- [ ] Todo alvo de toque tem no mínimo 48×48dp
- [ ] Golden tests passando

Commit: `feat(e02): design system com temas personalizáveis`
