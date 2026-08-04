import 'package:financa/design_system/components/app_form_field.dart';
import 'package:financa/design_system/components/auth_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _mobileAuthCallback = 'financa://auth-callback';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  var _loading = false;
  String? _message;
  var _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _message = 'Informe um e-mail válido.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : _mobileAuthCallback,
      );
      if (mounted) {
        setState(() {
          // Confirmação neutra de propósito: dizer que o e-mail existe
          // ou não permitiria enumerar quem tem conta no app.
          _message =
              'Se o e-mail estiver cadastrado, as instruções chegam em instantes.';
          _messageIsError = false;
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeadline(
                  title: 'Recuperar acesso',
                  subtitle:
                      'Informe seu e-mail para receber um link de redefinição.',
                ),
                const SizedBox(height: 26),
                AppFormField(
                  label: 'E-mail',
                  controller: _email,
                  hint: 'seu@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _loading ? null : _send(),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  AuthFeedbackBanner(
                    message: _message!,
                    isError: _messageIsError,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Enviar instruções'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({
    required this.onBack,
    required this.onPasswordUpdated,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onPasswordUpdated;

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _loading = false;
  var _obscurePassword = true;
  var _obscureConfirmation = true;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) widget.onPasswordUpdated();
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _loading ? null : widget.onBack,
          tooltip: 'Cancelar',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeadline(
                    title: 'Crie uma nova senha',
                    subtitle:
                        'Escolha uma senha com pelo menos 8 caracteres para proteger sua conta.',
                  ),
                  const SizedBox(height: 26),
                  AppFormField(
                    label: 'Nova senha',
                    controller: _password,
                    hint: 'Mínimo de 8 caracteres',
                    prefixIcon: Icons.lock_outline_rounded,
                    enabled: !_loading,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _validateNewPassword,
                    suffixIcon: IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppFormField(
                    label: 'Confirmar nova senha',
                    controller: _confirmation,
                    hint: 'Repita a senha',
                    prefixIcon: Icons.lock_outline_rounded,
                    enabled: !_loading,
                    obscureText: _obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (value != _password.text) {
                        return 'As senhas precisam ser iguais.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _updatePassword(),
                    suffixIcon: IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      tooltip: _obscureConfirmation
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    AuthFeedbackBanner(message: _message!, isError: true),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _updatePassword,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Salvar nova senha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Informe uma senha.';
  if (value.length < 8) return 'A senha precisa ter pelo menos 8 caracteres.';
  return null;
}
