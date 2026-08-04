import 'package:flutter/material.dart';

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
    required this.brand,
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
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color brand;
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
    inkFaint: Color(0xFF99A39D),
    line: Color(0xFFE4E7E1),
    brand: Color(0xFF23835F),
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
    canvas: Color(0xFF15201B),
    surface: Color(0xFF1B2922),
    surfaceRaised: Color(0xFF22332A),
    ink: Color(0xFFF2F4EC),
    inkMuted: Color(0xFFB9C4BC),
    inkFaint: Color(0xFF819088),
    line: Color(0xFF33463A),
    brand: Color(0xFF62C697),
    brandSoft: Color(0xFF224B39),
    income: Color(0xFF62C697),
    incomeSoft: Color(0xFF204632),
    expense: Color(0xFFFF987F),
    expenseSoft: Color(0xFF512C25),
    warning: Color(0xFFE8B65D),
    warningSoft: Color(0xFF513D20),
    coral: Color(0xFFF1A185),
    lilac: Color(0xFFB2A8E2),
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
    Color? brand,
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
      brand: brand ?? this.brand,
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
      brand: Color.lerp(brand, other.brand, t)!,
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
