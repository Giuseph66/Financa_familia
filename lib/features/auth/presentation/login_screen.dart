import 'package:financa/design_system/components/app_form_field.dart';
import 'package:financa/design_system/components/auth_layout.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/auth/presentation/widgets/auth_illustration.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entrada de quem já tem conta. Layout só-mobile, centralizado.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onShowSignup,
    this.onForgotPassword,
    super.key,
  });

  final VoidCallback onShowSignup;

  /// Quando informado, o pai abre o próprio fluxo de recuperação.
  /// Caso contrário esta tela pede o e-mail e chama o Supabase.
  final VoidCallback? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _isLoading = false;
  var _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Não foi possível entrar agora. Verifique sua conexão e tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final callback = widget.onForgotPassword;
    if (callback != null) {
      callback();
      return;
    }

    final email = await _showPasswordRecoveryDialog(
      initialEmail: _emailController.text.trim(),
    );
    if (!mounted || email == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(
        () => _infoMessage =
            'Se o e-mail estiver cadastrado, o link para redefinir a senha chega em instantes.',
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Não foi possível enviar o link agora. Verifique sua conexão e tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showPasswordRecoveryDialog({
    required String initialEmail,
  }) async {
    final controller = TextEditingController(text: initialEmail);
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Recuperar senha'),
            content: Form(
              key: formKey,
              child: AppFormField(
                label: 'E-mail',
                controller: controller,
                hint: 'seu@email.com',
                prefixIcon: Icons.mail_outline_rounded,
                autofocus: initialEmail.isEmpty,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  }
                },
                child: const Text('Enviar link'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AuthShell(
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AuthIllustration()),
                const SizedBox(height: 24),
                const AuthHeadline(
                  title: 'Bem-vindo',
                  subtitle: 'Entre para acessar sua conta',
                ),
                const SizedBox(height: 28),
                AppFormField(
                  label: 'E-mail',
                  controller: _emailController,
                  hint: 'seu@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                AppFormField(
                  label: 'Senha',
                  controller: _passwordController,
                  hint: 'Sua senha',
                  prefixIcon: Icons.lock_outline_rounded,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    onPressed: _isLoading
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
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  AuthFeedbackBanner(message: _errorMessage!, isError: true),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 8),
                  AuthFeedbackBanner(message: _infoMessage!, isError: false),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? Semantics(
                          label: 'Entrando',
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.inkFaint,
                            ),
                          ),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 22),
                const AuthOrDivider(),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : widget.onShowSignup,
                    child: const Text('Criar conta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Digite um e-mail válido.';
  }
  return null;
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Informe sua senha.';
  return null;
}

String _authErrorMessage(AuthException error) {
  final message = '${error.message} ${error.statusCode ?? ''}'.toLowerCase();

  // Credencial inválida nunca distingue "e-mail não existe" de "senha
  // errada": a diferença permite enumerar quem tem conta no app.
  if (message.contains('invalid login credentials') ||
      message.contains('invalid_credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (message.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
  }
  if (message.contains('network') || message.contains('fetch')) {
    return 'Não foi possível conectar. Verifique sua internet e tente de novo.';
  }

  return 'Não foi possível concluir agora. Confira os dados e tente de novo.';
}
