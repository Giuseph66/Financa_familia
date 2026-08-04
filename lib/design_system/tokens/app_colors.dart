import 'package:flutter/material.dart';

/// Paleta do app.
///
/// O dark é neutro e quase preto. Os neutros não têm matiz azul: o azul
/// aparece só no acento de marca, e é isso que faz ele ser lido como
/// acento em vez de se dissolver no fundo.
///
/// Contrastes conferidos contra `canvas` (#0A0A0C):
///   ink 18,0:1 · inkMuted 8,4:1 · inkFaint 5,2:1 · brandInk 9,3:1
///   income 9,8:1 · expense 8,5:1 · warning 11,5:1
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.brand,
    required this.brandInk,
    required this.brandSoft,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.warning,
    required this.warningSoft,
    required this.coral,
    required this.lilac,
  });

  /// Fundo da aplicação. Quase preto, mas não #000: preto puro provoca
  /// arrasto em OLED durante a rolagem e faz o texto claro vibrar.
  final Color canvas;

  /// Um degrau acima do canvas: conteúdo agrupado, campos, ilustração.
  final Color surface;

  /// Dois degraus acima: modal, folha e seleção.
  final Color surfaceRaised;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  /// Separador e borda decorativa. Não serve para delimitar controle.
  final Color line;

  /// Contorno de controle interativo — campo, botão de contorno.
  ///
  /// Existe separado de [line] por causa do fundo quase preto: uma
  /// borda discreta o bastante para separar seções fica invisível como
  /// limite de campo. Esta atinge 3:1 contra o canvas, que é o mínimo
  /// do WCAG para elemento de interface não textual.
  final Color lineStrong;

  /// Preenchimento de ação primária, foco e ícone. Exigência é 3:1.
  final Color brand;

  /// Marca em texto. Existe porque [brand] como texto não alcança 4,5:1.
  /// Use em link, TextButton e rótulo em foco.
  final Color brandInk;

  final Color brandSoft;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color warning;
  final Color warningSoft;
  final Color coral;
  final Color lilac;

  static const light = AppColors(
    canvas: Color(0xFFF5F4EF),
    surface: Color(0xFFFCFBF8),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF193129),
    inkMuted: Color(0xFF65716B),
    inkFaint: Color(0xFF6E7873),
    line: Color(0xFFE4E7E1),
    lineStrong: Color(0xFF8C8F88),
    brand: Color(0xFF23835F),
    brandInk: Color(0xFF1B6B4C),
    brandSoft: Color(0xFFDCEFE5),
    income: Color(0xFF23835F),
    incomeSoft: Color(0xFFE1F3E9),
    expense: Color(0xFFC4402C),
    expenseSoft: Color(0xFFFBE6DF),
    warning: Color(0xFFB87922),
    warningSoft: Color(0xFFFFF0D5),
    coral: Color(0xFFE98B70),
    lilac: Color(0xFF8B7FBC),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0A0A0C),
    surface: Color(0xFF131316),
    surfaceRaised: Color(0xFF1C1C21),
    ink: Color(0xFFF4F4F6),
    inkMuted: Color(0xFFA8A8B3),
    inkFaint: Color(0xFF82828E),
    line: Color(0xFF2C2C33),
    lineStrong: Color(0xFF5C5C66),
    // Mantido: com `ink` por cima dá 4,85:1, e clarear o azul para ele
    // saltar mais do preto derrubaria o rótulo do botão abaixo de 4,5.
    brand: Color(0xFF416F96),
    brandInk: Color(0xFF8FB6D8),
    brandSoft: Color(0xFF16202B),
    income: Color(0xFF68C991),
    incomeSoft: Color(0xFF10241A),
    expense: Color(0xFFF28E86),
    expenseSoft: Color(0xFF2A1614),
    warning: Color(0xFFF2BD67),
    warningSoft: Color(0xFF2A2113),
    coral: Color(0xFFD7A55D),
    lilac: Color(0xFFA6B8D1),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? brand,
    Color? brandInk,
    Color? brandSoft,
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? warning,
    Color? warningSoft,
    Color? coral,
    Color? lilac,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      brand: brand ?? this.brand,
      brandInk: brandInk ?? this.brandInk,
      brandSoft: brandSoft ?? this.brandSoft,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      coral: coral ?? this.coral,
      lilac: lilac ?? this.lilac,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      lilac: Color.lerp(lilac, other.lilac, t)!,
    );
  }
}
