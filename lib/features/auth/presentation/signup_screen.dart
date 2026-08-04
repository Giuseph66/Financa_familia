import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            ? 'Conta criada! Confira seu e-mail para confirmar o cadastro.'
            : 'Conta criada com sucesso!';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Não foi possível criar sua conta agora. Verifique sua conexão e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.canvas, colors.canvas, colors.brandSoft],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final horizontalPadding = constraints.maxWidth >= 560 ? 40.0 : 20.0;
              final verticalPadding = wide ? 40.0 : 24.0;
              final minHeight = constraints.maxHeight > verticalPadding * 2
                  ? constraints.maxHeight - verticalPadding * 2
                  : 0.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 1120,
                    minHeight: minHeight,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(child: _SignupIntro()),
                            const SizedBox(width: 64),
                            SizedBox(width: 440, child: _buildCard(colors)),
                          ],
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _buildCard(colors),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppColors colors) {
    return Material(
      color: colors.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthBrand(),
                const SizedBox(height: 28),
                Text(
                  'Crie seu espaço',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Comece a organizar sua vida financeira em poucos passos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Como você quer ser chamado?',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    hintText: 'Mínimo de 8 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                      ),
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                    ),
                  ),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  _FeedbackBanner(message: _errorMessage!, isError: true),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 18),
                  _FeedbackBanner(message: _infoMessage!, isError: false),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? Semantics(
                            label: 'Criando sua conta',
                            child: SizedBox.square(
                              dimension: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.ink,
                              ),
                            ),
                          )
                        : const Text('Criar minha conta'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ao continuar, você concorda em usar a Finança para cuidar dos seus dados financeiros.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.inkFaint,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Já tem uma conta?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : widget.onShowLogin,
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupIntro extends StatelessWidget {
  const _SignupIntro();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AuthBrand(),
          const SizedBox(height: 46),
          Text(
            'Um começo leve\npara seus planos.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 48,
              height: 1.05,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Text(
              'Tenha um lugar claro para acompanhar sua casa, seus objetivos e cada pequena conquista.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.inkMuted,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(height: 34),
          const _Benefit(
            icon: Icons.edit_note_rounded,
            text: 'Registre o que acontece sem complicar.',
          ),
          const SizedBox(height: 14),
          const _Benefit(
            icon: Icons.favorite_border_rounded,
            text: 'Cuide do dinheiro com mais tranquilidade.',
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: colors.brand),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      header: true,
      label: 'Finança',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.brand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: colors.ink,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Text(
              'Finança',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = isError ? colors.expense : colors.brand;
    final background = isError ? colors.expenseSoft : colors.brandSoft;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${isError ? 'Erro: ' : ''}$message',
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: foreground.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: foreground,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
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
    return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
  }
  if (message.contains('network') || message.contains('fetch')) {
    return 'Não foi possível conectar. Verifique sua internet e tente novamente.';
  }

  return 'Não foi possível criar sua conta. Confira os dados e tente novamente.';
}
