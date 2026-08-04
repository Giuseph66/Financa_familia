import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.canvasSunken,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
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

  final Color canvas;

  /// Mais escuro que [canvas]. Usado em controles que devem parecer
  /// escavados na superfície em vez de apoiados sobre ela — campos de
  /// entrada, principalmente. É o que permite a tela ter uma única
  /// coisa elevada: a ação primária.
  final Color canvasSunken;

  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color brand;

  /// Marca em texto sobre o canvas. Existe porque [brand] como texto
  /// atinge apenas 3,37:1 no dark — reprova no WCAG AA. Use em link,
  /// TextButton e rótulo em foco; [brand] fica para preenchimento,
  /// borda e ícone, onde a exigência de contraste é 3:1.
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
    canvasSunken: Color(0xFFEAE8E0),
    surface: Color(0xFFFCFBF8),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF193129),
    inkMuted: Color(0xFF65716B),
    inkFaint: Color(0xFF99A39D),
    line: Color(0xFFE4E7E1),
    brand: Color(0xFF23835F),
    brandInk: Color(0xFF1B6B4C), // 5,86:1 sobre canvas claro
    brandSoft: Color(0xFFDCEFE5),
    income: Color(0xFF23835F),
    incomeSoft: Color(0xFFE1F3E9),
    expense: Color(0xFFD96755),
    expenseSoft: Color(0xFFFBE6DF),
    warning: Color(0xFFB87922),
    warningSoft: Color(0xFFFFF0D5),
    coral: Color(0xFFE98B70),
    lilac: Color(0xFF8B7FBC),
  );

  static const dark = AppColors(
    canvas: Color(0xFF111722),
    canvasSunken: Color(0xFF080D15),
    surface: Color(0xFF18212E),
    surfaceRaised: Color(0xFF222D3D),
    ink: Color(0xFFF2F5FA),
    inkMuted: Color(0xFFB4C0CF),
    inkFaint: Color(0xFF8E9CAF),
    line: Color(0xFF3A475B),
    brand: Color(0xFF416F96),
    brandInk: Color(0xFF8FB6D8), // 8,42:1 sobre canvas escuro
    brandSoft: Color(0xFF22354A),
    income: Color(0xFF68C991),
    incomeSoft: Color(0xFF1F3F30),
    expense: Color(0xFFF28E86),
    expenseSoft: Color(0xFF4D2B30),
    warning: Color(0xFFF2BD67),
    warningSoft: Color(0xFF49371D),
    coral: Color(0xFFD7A55D),
    lilac: Color(0xFFA6B8D1),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? canvasSunken,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
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
      canvasSunken: canvasSunken ?? this.canvasSunken,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
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
      canvasSunken: Color.lerp(canvasSunken, other.canvasSunken, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
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
