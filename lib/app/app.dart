import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FinancaApp extends StatelessWidget {
  const FinancaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finança',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt')],
      home: const DashboardScreen(),
    );
  }
}
