import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/auth/presentation/forgot_password_screen.dart';
import 'package:financa/features/auth/presentation/login_screen.dart';
import 'package:financa/features/auth/presentation/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduz a troca de tela do AuthGate: AnimatedSwitcher alternando
/// LoginScreen e SignupScreen, cada uma com Form(GlobalKey) dentro de
/// AutofillGroup.
enum _Route { login, signup, forgot }

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var _route = _Route.login;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (_route) {
          _Route.login => LoginScreen(
            key: const ValueKey('login'),
            onShowSignup: () => setState(() => _route = _Route.signup),
            onForgotPassword: () => setState(() => _route = _Route.forgot),
          ),
          _Route.signup => SignupScreen(
            key: const ValueKey('signup'),
            onShowLogin: () => setState(() => _route = _Route.login),
          ),
          _Route.forgot => ForgotPasswordScreen(
            key: const ValueKey('forgot'),
            onBack: () => setState(() => _route = _Route.login),
          ),
        },
      ),
    );
  }
}

void main() {
  testWidgets('alternar login/signup com campo focado não estoura', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    // Foca e digita, como o usuário fez antes do crash.
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.pump();

    // Troca de tela enquanto o campo ainda está focado e registrado no
    // AutofillGroup — é o caminho que o AuthGate percorre.
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Criar minha conta'), findsOneWidget);

    // E volta.
    await tester.ensureVisible(find.text('Entrar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo'), findsOneWidget);
  });

  testWidgets('login -> esqueci a senha -> voltar, com campo focado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.pump();

    await tester.ensureVisible(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar acesso'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo'), findsOneWidget);
  });
}
