import 'package:financa/design_system/components/app_form_field.dart';
import 'package:financa/design_system/components/auth_layout.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/auth/presentation/widgets/auth_illustration.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Criação de conta. Mesma moldura do login: o fluxo inteiro tem que
/// parecer o mesmo app.
class SignupScreen extends StatefulWidget {
  const SignupScreen({required this.onShowLogin, super.key});

  final VoidCallback onShowLogin;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _isLoading = false;
  var _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'display_name': _nameController.text.trim()},
      );

      if (!mounted) return;
      setState(() {
        _infoMessage = response.session == null
            ? 'Conta criada. Confira seu e-mail para confirmar o cadastro.'
            : 'Conta criada com sucesso.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Não foi possível criar sua conta agora. Verifique sua conexão e tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                // Menor que no login: aqui há um campo a mais e a
                // ilustração não pode empurrar o formulário para fora
                // da primeira dobra.
                const Center(child: AuthIllustration(height: 150)),
                const SizedBox(height: 22),
                const AuthHeadline(
                  title: 'Criar conta',
                  subtitle: 'Comece a organizar o dinheiro da sua casa',
                ),
                const SizedBox(height: 26),
                AppFormField(
                  label: 'Nome',
                  controller: _nameController,
                  hint: 'Como você quer ser chamado',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: _validateName,
                ),
                const SizedBox(height: 18),
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
                  hint: 'Mínimo de 8 caracteres',
                  prefixIcon: Icons.lock_outline_rounded,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  AuthFeedbackBanner(message: _errorMessage!, isError: true),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 16),
                  AuthFeedbackBanner(message: _infoMessage!, isError: false),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? Semantics(
                          label: 'Criando sua conta',
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.inkFaint,
                            ),
                          ),
                        )
                      : const Text('Criar minha conta'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ao continuar, você concorda em usar a Finança para cuidar dos seus dados financeiros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.inkFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                const AuthOrDivider(),
                const SizedBox(height: 4),
                AuthSwitchPrompt(
                  question: 'Já tem uma conta?',
                  action: 'Entrar',
                  onPressed: _isLoading ? null : widget.onShowLogin,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String? _validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Informe seu nome.';
  if (name.length < 2) return 'Digite seu nome completo.';
  return null;
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
  if (value == null || value.isEmpty) return 'Informe uma senha.';
  if (value.length < 8) return 'A senha precisa ter pelo menos 8 caracteres.';
  return null;
}

String _authErrorMessage(AuthException error) {
  final message = '${error.message} ${error.statusCode ?? ''}'.toLowerCase();

  if (message.contains('already registered') ||
      message.contains('user already exists') ||
      message.contains('email_exists')) {
    return 'Este e-mail já está cadastrado. Tente entrar.';
  }
  if (message.contains('password') &&
      (message.contains('8') || message.contains('weak'))) {
    return 'Escolha uma senha com pelo menos 8 caracteres.';
  }
  if (message.contains('invalid') && message.contains('email')) {
    return 'Digite um e-mail válido.';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
  }
  if (message.contains('network') || message.contains('fetch')) {
    return 'Não foi possível conectar. Verifique sua internet e tente de novo.';
  }

  return 'Não foi possível criar sua conta. Confira os dados e tente de novo.';
}
