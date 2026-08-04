import 'package:financa/design_system/tokens/app_colors.dart';
import 'package:financa/design_system/tokens/radii.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;
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
      onPrimary: isDark ? colors.ink : Colors.white,
      primaryContainer: isDark ? colors.brandSoft : scheme.primaryContainer,
      onPrimaryContainer: isDark
          ? colors.brand
          : scheme.onPrimaryContainer,
      secondary: isDark ? colors.warning : scheme.secondary,
      onSecondary: isDark ? colors.canvas : scheme.onSecondary,
      secondaryContainer: isDark
          ? colors.warningSoft
          : scheme.secondaryContainer,
      onSecondaryContainer: isDark
          ? colors.ink
          : scheme.onSecondaryContainer,
      tertiary: isDark ? colors.lilac : scheme.tertiary,
      onTertiary: isDark ? colors.canvas : scheme.onTertiary,
      tertiaryContainer: isDark
          ? colors.surfaceRaised
          : scheme.tertiaryContainer,
      onTertiaryContainer: isDark
          ? colors.lilac
          : scheme.onTertiaryContainer,
      surface: colors.surface,
      onSurface: colors.ink,
      surfaceContainerHighest: isDark
          ? colors.surfaceRaised
          : scheme.surfaceContainerHighest,
      onSurfaceVariant: isDark ? colors.inkMuted : scheme.onSurfaceVariant,
      outline: colors.line,
      outlineVariant: isDark ? colors.line : scheme.outlineVariant,
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
      // Micro-rótulo persistente acima de campos e seções. Caixa alta
      // com tracking aberto para funcionar em 11px sem virar ruído.
      labelSmall: TextStyle(
        color: colors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),

    // Em canvas quase preto não existe headroom para baixo: campo
    // afundado seria invisível. O campo sobe um degrau e quem define o
    // limite é a borda, que por isso usa lineStrong (3:1) e não line.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: TextStyle(color: colors.inkFaint, fontSize: 16),
      labelStyle: TextStyle(color: colors.inkMuted, fontSize: 16),
      floatingLabelStyle: TextStyle(color: colors.brandInk, fontSize: 13),
      prefixIconColor: colors.inkFaint,
      suffixIconColor: colors.inkFaint,
      errorStyle: TextStyle(color: colors.expense, fontSize: 12, height: 1.3),
      border: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.expense, width: 2),
      ),
      // Desabilitado pode cair abaixo de 3:1: o controle está fora de
      // uso e a baixa saliência é a informação.
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: BorderSide(color: colors.lineStrong.withValues(alpha: 0.4)),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: colors.brand,
        foregroundColor: isDark ? colors.ink : Colors.white,
        disabledBackgroundColor: colors.surfaceRaised,
        disabledForegroundColor: colors.inkFaint,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.lineStrong),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    // brandInk, não brand: link é texto e precisa de 4,5:1.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.brandInk,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    // Sem cor própria e sem tinta de elevação: com canvas quase preto,
    // a AppBar padrão do M3 desenha uma faixa mais clara no topo que
    // não corresponde a nenhuma separação real de conteúdo.
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
      titleTextStyle: TextStyle(
        color: colors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceRaised,
      contentTextStyle: TextStyle(color: colors.ink, fontSize: 14),
      actionTextColor: colors.brandInk,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
    ),
  );
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
