import 'package:financa/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.brand,
    brightness: brightness,
    surface: colors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      primary: colors.brand,
      onPrimary: brightness == Brightness.dark ? colors.ink : Colors.white,
      surface: colors.surface,
      onSurface: colors.ink,
      outline: colors.line,
    ),
    scaffoldBackgroundColor: colors.canvas,
    extensions: [colors],
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: colors.ink,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: TextStyle(
        color: colors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: colors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: colors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: colors.ink, fontSize: 15, height: 1.4),
      bodyMedium: TextStyle(color: colors.inkMuted, fontSize: 13, height: 1.35),
      labelLarge: TextStyle(
        color: colors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        color: colors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
