# 08 — Design System

## Objetivo

Um sistema **simples de usar e fácil de retematizar**. Trocar a cor de marca, o arredondamento ou a densidade deve ser uma linha em um arquivo, não uma caçada por 40 widgets.

Duas regras que o executor não pode violar:

**Nenhum valor bruto em widget de feature.** Nada de `Color(0xFF...)`, `EdgeInsets.all(16)` ou `BorderRadius.circular(12)` fora de `design_system/`. Tudo vem de token. Isto é o que torna o tema realmente trocável — e é a primeira coisa a conferir em revisão de código.

**Nenhuma string de UI hardcoded.** Tudo por `context.l10n`. Custa nada agora e é impagável quando alguém pedir a versão em inglês.

## Camadas

```
tokens/     → valores crus: cores, espaços, raios, durações
theme/      → ThemePreset + ThemeExtension: monta o ThemeData
components/ → widgets que só consomem token
gallery/    → rota /dev/ds, catálogo visual de tudo
```

## Tokens

### Cor

Base em Material 3: uma cor semente gera o esquema inteiro por algoritmo, o que garante contraste correto em claro e escuro sem escolher 30 cores à mão.

O que o M3 **não** dá é o vocabulário financeiro. Isso entra via `ThemeExtension`:

```dart
// lib/design_system/tokens/app_colors.dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,        required this.onIncome,
    required this.incomeSurface,
    required this.expense,       required this.onExpense,
    required this.expenseSurface,
    required this.transfer,      required this.neutral,
    required this.warning,       required this.warningSurface,
    required this.success,       required this.danger,
    required this.memberPalette,
    required this.surfaceRaised, required this.surfaceSunken,
    required this.divider,       required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Color income, onIncome, incomeSurface;
  final Color expense, onExpense, expenseSurface;
  final Color transfer, neutral;
  final Color warning, warningSurface, success, danger;
  final Color surfaceRaised, surfaceSunken, divider;
  final Color shimmerBase, shimmerHighlight;

  /// Cores de membro. Cada pessoa tem uma cor fixa em todos os
  /// gráficos do app — é o que torna o comparativo legível sem ler
  /// legenda. Dez tons distinguíveis, testados também para
  /// deuteranopia (o par verde/vermelho de entrada e saída NUNCA é
  /// usado aqui, justamente para não colidir).
  final List<Color> memberPalette;

  static const _lightMembers = [
    Color(0xFF6750A4), Color(0xFF00696D), Color(0xFF8B5000),
    Color(0xFF3F5AA9), Color(0xFF8C4A60), Color(0xFF4C6444),
    Color(0xFF7D5260), Color(0xFF006874), Color(0xFF984061),
    Color(0xFF565992),
  ];

  factory AppColors.light(ColorScheme s) => AppColors(
        income:         const Color(0xFF1B6E3C),
        onIncome:       Colors.white,
        incomeSurface:  const Color(0xFFD7F2E0),
        expense:        const Color(0xFFB3261E),
        onExpense:      Colors.white,
        expenseSurface: const Color(0xFFFCE8E6),
        transfer:       const Color(0xFF445E91),
        neutral:        s.onSurfaceVariant,
        warning:        const Color(0xFF8F5000),
        warningSurface: const Color(0xFFFFDDB3),
        success:        const Color(0xFF1B6E3C),
        danger:         s.error,
        surfaceRaised:  s.surfaceContainerLow,
        surfaceSunken:  s.surfaceContainerHighest,
        divider:        s.outlineVariant,
        shimmerBase:    s.surfaceContainerHighest,
        shimmerHighlight: s.surfaceContainerLowest,
        memberPalette:  _lightMembers,
      );

  factory AppColors.dark(ColorScheme s) => AppColors(
        // No escuro, verde e vermelho puros vibram sobre fundo escuro
        // e cansam a vista. Tons dessaturados mantêm o significado sem
        // o efeito neon.
        income:         const Color(0xFF7ADBA0),
        onIncome:       const Color(0xFF00391C),
        incomeSurface:  const Color(0xFF1F4A32),
        expense:        const Color(0xFFFFB4AB),
        onExpense:      const Color(0xFF690005),
        expenseSurface: const Color(0xFF5C1B17),
        transfer:       const Color(0xFFB0C6FF),
        // ... demais análogos
        memberPalette:  _darkMembers,
      );

  @override
  AppColors copyWith({ /* todos os campos */ }) => /* ... */;

  @override
  AppColors lerp(AppColors? other, double t) => /* Color.lerp campo a campo */;
}
```

Extensão de acesso, para o consumo ficar curto:

```dart
extension AppThemeX on BuildContext {
  AppColors  get colors  => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme  get text    => Theme.of(this).textTheme;
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
```

Uso: `context.colors.expense`.

#### Verde e vermelho não podem ser o único sinal

Cerca de 8% dos homens têm alguma deficiência de visão de cores. Entrada e saída **sempre** carregam um segundo sinal redundante:

- o **sinal** no valor: `+ R$ 1.200,00` / `− R$ 32,90`;
- o **ícone** direcional: seta para baixo em entrada, para cima em saída;
- a **posição** nos relatórios: entradas acima, saídas abaixo, sempre.

Cor é reforço, nunca a informação em si.

### Espaçamento

Escala de 4pt. Nomes, não números — o desenvolvedor escolhe intenção, não pixel:

```dart
abstract final class Spacing {
  static const none = 0.0;
  static const xxs = 2.0;
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;   // padding padrão de tela
  static const xl  = 24.0;   // entre seções
  static const xxl = 32.0;
  static const huge = 48.0;

  static const screenPadding = EdgeInsets.symmetric(horizontal: lg);
  static const cardPadding   = EdgeInsets.all(lg);
  static const listItemPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
}
```

### Raio

```dart
abstract final class Radii {
  static const sm   = Radius.circular(8);
  static const md   = Radius.circular(12);
  static const lg   = Radius.circular(16);
  static const xl   = Radius.circular(24);
  static const pill = Radius.circular(999);

  static const card   = BorderRadius.all(lg);
  static const sheet  = BorderRadius.vertical(top: xl);
  static const chip   = BorderRadius.all(pill);
  static const button = BorderRadius.all(md);
}
```

`CornerStyle` no preset permite trocar o conjunto inteiro entre `sharp`, `rounded` e `pill` — uma escolha do usuário que muda a personalidade do app sem tocar em componente.

### Tipografia

Fonte **Inter Variable**, embarcada em `assets/fonts/`. Embarcada, não do Google Fonts em runtime: o app precisa funcionar offline, e baixar fonte no primeiro boot causa um salto visual feio.

O detalhe que mais importa aqui:

```dart
abstract final class AppTypography {
  /// Dígitos de largura fixa. SEM isto, uma coluna de valores fica
  /// desalinhada porque o "1" é mais estreito que o "8", e uma lista
  /// de lançamentos vira uma serra. É a diferença entre parecer um
  /// app financeiro e parecer um formulário.
  static const _tabular = [FontFeature.tabularFigures()];

  static const money = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: _tabular,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,      // números grandes respiram melhor apertados
  );

  static TextTheme build(ColorScheme s, double scale) => TextTheme(
        displayLarge:  TextStyle(fontSize: 44 * scale, fontWeight: FontWeight.w700,
                                 fontFeatures: _tabular, letterSpacing: -1.0),
        headlineMedium:TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.w600),
        titleMedium:   TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
        bodyLarge:     TextStyle(fontSize: 16 * scale),
        bodyMedium:    TextStyle(fontSize: 14 * scale),
        labelSmall:    TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w500),
      ).apply(fontFamily: 'Inter');
}
```

`displayLarge` também é tabular porque é o estilo do saldo grande no topo do dashboard — sem isso, o número "pula" a cada centavo que muda.

### Movimento

```dart
abstract final class Motion {
  static const instant = Duration(milliseconds: 100);
  static const fast    = Duration(milliseconds: 180);
  static const normal  = Duration(milliseconds: 260);
  static const slow    = Duration(milliseconds: 400);

  static const enter = Curves.easeOutCubic;    // entrada desacelera
  static const exit  = Curves.easeInCubic;     // saída acelera
  static const emphasized = Cubic(0.2, 0, 0, 1);
}
```

Teto de 400ms. Animação mais longa que isso num app usado em pé, na fila do mercado, é obstáculo. E **respeite `MediaQuery.disableAnimations`** — quem ligou "reduzir movimento" no sistema pediu isso por um motivo, frequentemente vestibular:

```dart
Duration d(BuildContext c, Duration base) =>
    MediaQuery.disableAnimationsOf(c) ? Duration.zero : base;
```

## O preset de tema

O objeto que o usuário edita em Ajustes › Aparência. Persistido em `app_settings`, sincronizado por dispositivo (não pela casa — cada pessoa escolhe o seu).

```dart
@freezed
sealed class ThemePreset with _$ThemePreset {
  const factory ThemePreset({
    required String id,
    required String name,
    required int seedColor,
    @Default(ThemeMode.system) ThemeMode mode,
    @Default(false) bool useDynamicColor,   // Material You (Android 12+)
    @Default(CornerStyle.rounded) CornerStyle corners,
    @Default(Density.comfortable) Density density,
    @Default(1.0) double fontScale,
    @Default(true) bool showCents,
    @Default(false) bool colorBlindSafe,    // troca verde/vermelho por azul/laranja
  }) = _ThemePreset;

  static const presets = [
    ThemePreset(id: 'default', name: 'Padrão',   seedColor: 0xFF6750A4),
    ThemePreset(id: 'forest',  name: 'Floresta', seedColor: 0xFF2E7D32),
    ThemePreset(id: 'ocean',   name: 'Oceano',   seedColor: 0xFF0277BD),
    ThemePreset(id: 'sunset',  name: 'Pôr do sol', seedColor: 0xFFD84315),
    ThemePreset(id: 'graphite',name: 'Grafite',  seedColor: 0xFF455A64),
    ThemePreset(id: 'rose',    name: 'Rosé',     seedColor: 0xFFAD1457),
  ];
}
```

Montagem do `ThemeData`:

```dart
ThemeData buildTheme(ThemePreset p, Brightness b, ColorScheme? dynamicScheme) {
  final scheme = (p.useDynamicColor && dynamicScheme != null)
      ? dynamicScheme.harmonized()
      : ColorScheme.fromSeed(seedColor: Color(p.seedColor), brightness: b);

  final colors = b == Brightness.light
      ? AppColors.light(scheme)
      : AppColors.dark(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: AppTypography.build(scheme, p.fontScale),
    visualDensity: p.density.toVisualDensity(),
    extensions: [
      p.colorBlindSafe ? colors.toColorBlindSafe() : colors,
      AppShapes.from(p.corners),
    ],
    // ... temas de componente derivados dos mesmos tokens
  );
}
```

`showCents` existe porque quem controla orçamento doméstico costuma pensar em reais inteiros, e `R$ 1.234` lê mais rápido que `R$ 1.234,56`. Afeta só a exibição — o dado armazenado nunca perde precisão.

## Componentes

### `MoneyText` — o componente mais usado do app

```dart
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.kind,                      // pinta e escolhe o sinal
    this.size = MoneySize.body,
    this.showSign = true,
    this.obscured = false,          // modo privacidade: R$ ••••
  });

  final int cents;
  final TransactionKind? kind;
  ...
}
```

Responsabilidades: formatar em pt-BR, aplicar a cor semântica pelo `kind`, prefixar o sinal, usar dígitos tabulares, e respeitar `showCents` e o modo privacidade. Centralizar isso significa que a decisão "como dinheiro aparece neste app" mora em um arquivo só.

O **modo privacidade** (`obscured`) é um toque no saldo do dashboard e esconde todos os valores. Serve para abrir o app no ônibus sem exibir o salário para quem está ao lado. Estado global, não por tela.

### Catálogo completo

**Átomos** — `MoneyText`, `AppIcon`, `AppChip`, `AppDivider`, `AppAvatar` (foto, emoji ou iniciais com a cor do membro), `Skeleton`, `AppBadge`, `AppSwitch`, `SignedIcon`.

**Moléculas** — `AppButton` (`filled` / `tonal` / `outlined` / `text` / `destructive`), `AppTextField`, `AmountInput` (teclado numérico próprio, ver [10](10-entrada-rapida.md)), `CategoryChip`, `CategoryGrid`, `AccountChip`, `MemberChip`, `DateChip`, `AppCard`, `StatTile`, `ProgressBar`, `BudgetBar` (com marcador no `alert_pct`), `EmptyState`, `AppSnackBar`, `SegmentedToggle`, `FilterBar`, `Sparkline`.

**Organismos** — `TransactionTile` (avatar da categoria, descrição, membro, valor, indicador de anexo e de pendência de sync), `TransactionList` (agrupada por dia, com cabeçalho pegajoso e total do dia), `AccountCard`, `MonthNavigator`, `CategoryBreakdown` (rosca + lista), `MemberComparisonChart` (barras lado a lado — a tela-assinatura do produto), `TrendChart` (linha de 12 meses), `UpcomingBillsCard`, `QuickAddSheet`, `AppScaffold`, `AppBottomNav`.

Regra sobre estados: **todo componente que carrega dado precisa dos quatro** — carregando (skeleton, nunca spinner em lista), vazio (com ilustração e ação de saída), erro (com botão de tentar de novo) e conteúdo. Tela sem estado vazio é a que mais recebe reclamação, porque é a primeira que o usuário novo vê.

## A galeria

Rota `/dev/ds`, disponível só quando `Env.isDev`. Lista todos os componentes em todos os estados, com controles ao vivo para trocar preset, alternar claro/escuro, mudar escala de fonte, densidade e modo daltônico.

Não é enfeite. É onde se descobre que o botão destrutivo some no tema escuro, ou que o texto quebra com `fontScale = 1.3`. Encontrar isso na galeria custa segundos; encontrar em produção custa um relatório de bug e um ciclo de release.

Adicionar uma entrada na galeria é parte do DoD de todo componente novo.

## Acessibilidade

Não é etapa final — é critério de aceite de cada componente.

- **Alvo de toque mínimo 48×48 dp**, sempre. Botão de ícone com `IconButton` já garante; `GestureDetector` cru não.
- **Contraste mínimo 4,5:1** para texto normal, 3:1 para texto grande. O `ColorScheme.fromSeed` cuida das cores geradas; as cores customizadas de `AppColors` foram escolhidas para passar e precisam ser reverificadas se alguém mexer.
- **`Semantics` em todo dado não textual.** Um gráfico sem `Semantics` é invisível para leitor de tela. `MoneyText` anuncia "trinta e dois reais e noventa centavos, despesa", não "menos 32,90".
- **Escala de fonte do sistema respeitada até 200%.** Nada de `TextScaler.noScaling`. Teste a tela de entrada rápida em 200% — é onde quebra primeiro.
- **`disableAnimations` respeitado** em toda animação.

## Modo escuro

Não é inversão. Regras próprias:

- Superfícies **não** são preto puro (`#000`): `surfaceContainerLowest` do M3, para evitar smearing em OLED e reduzir o contraste agressivo.
- Elevação no escuro se expressa por **cor mais clara**, não por sombra — sombra é invisível sobre fundo escuro.
- Cores semânticas dessaturadas, conforme mostrado em `AppColors.dark`.
- Imagem de recibo ganha uma leve borda, para não sangrar no fundo.

O padrão é `ThemeMode.system`. Ninguém deveria precisar entrar em Ajustes para o app parecer certo.
