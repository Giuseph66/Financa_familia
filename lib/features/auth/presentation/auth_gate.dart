import 'dart:async';

import 'package:financa/features/auth/presentation/forgot_password_screen.dart';
import 'package:financa/features/auth/presentation/login_screen.dart';
import 'package:financa/features/auth/presentation/signup_screen.dart';
import 'package:financa/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;
  var _route = _AuthRoute.login;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        _session = state.session;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _route = _AuthRoute.updatePassword;
        } else if (state.event == AuthChangeEvent.signedOut &&
            _route == _AuthRoute.updatePassword) {
          _route = _AuthRoute.login;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_route == _AuthRoute.updatePassword) {
      return UpdatePasswordScreen(
        key: const ValueKey('update-password'),
        onBack: _cancelPasswordRecovery,
        onPasswordUpdated: () {
          if (!mounted) return;
          setState(() => _route = _AuthRoute.login);
        },
      );
    }

    if (_session != null) return const DashboardScreen();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_route) {
        _AuthRoute.login => LoginScreen(
          key: const ValueKey('login'),
          onShowSignup: () => setState(() => _route = _AuthRoute.signup),
          onForgotPassword: () =>
              setState(() => _route = _AuthRoute.forgot),
        ),
        _AuthRoute.signup => SignupScreen(
          key: const ValueKey('signup'),
          onShowLogin: () => setState(() => _route = _AuthRoute.login),
        ),
        _AuthRoute.forgot => ForgotPasswordScreen(
          key: const ValueKey('forgot'),
          onBack: () => setState(() => _route = _AuthRoute.login),
        ),
        _AuthRoute.updatePassword => const SizedBox.shrink(),
      },
    );
  }

  void _cancelPasswordRecovery() {
    unawaited(_signOutFromPasswordRecovery());
  }

  Future<void> _signOutFromPasswordRecovery() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException {
      if (!mounted) return;
      setState(() => _route = _AuthRoute.login);
    }
  }
}

enum _AuthRoute { login, signup, forgot, updatePassword }
