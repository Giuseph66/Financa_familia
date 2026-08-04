import 'package:financa/core/supabase/supabase_bootstrap.dart';
import 'package:financa/core/supabase/supabase_configuration_screen.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/auth/presentation/auth_gate.dart';
import 'package:financa/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FinancaApp extends StatelessWidget {
  const FinancaApp({required this.bootstrap, super.key});

  final SupabaseBootstrapResult bootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finança',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: bootstrap.isReady
          ? const AuthGate()
          : SupabaseConfigurationScreen(
              configuration: bootstrap.configuration,
              initializationError: bootstrap.initializationError,
            ),
    );
  }
}
