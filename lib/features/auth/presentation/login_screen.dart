import 'package:financa/design_system/components/app_form_field.dart';
import 'package:financa/design_system/components/brand_lockup.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entrada de quem já tem conta.
///
/// Layout só-mobile e sem card: em tela cheia de celular o card é
/// chrome redundante — a tela já é o recipiente. O formulário fica no
/// canvas nu, com o cabeçalho no topo e a ação ao alcance do polegar.
///
/// A tela tem exatamente um elemento elevado, e ele é a ação. Campos
/// são escavados (`canvasSunken`), o resto é canvas.
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _entrance;

  var _isLoading = false;
  var _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Um único momento de entrada, e nada mais se move sozinho depois.
    // Quem pediu redução de movimento recebe o estado final direto.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
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
                hint: 'voce@exemplo.com',
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

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: IntrinsicHeight(
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Staggered(
                            controller: _entrance,
                            begin: 0,
                            end: 0.62,
                            child: const _Header(),
                          ),
                          const SizedBox(height: 40),
                          _Staggered(
                            controller: _entrance,
                            begin: 0.22,
                            end: 1,
                            child: _buildForm(),
                          ),
                          // O vazio fica entre a ação e o rodapé, não
                          // no meio do conteúdo. O rodapé é saída
                          // secundária e pertence à borda inferior.
                          const Expanded(child: SizedBox(height: 32)),
                          const SizedBox(height: 24),
                          _Staggered(
                            controller: _entrance,
                            begin: 0.3,
                            end: 1,
                            child: _SignupPrompt(
                              onPressed: _isLoading ? null : widget.onShowSignup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFormField(
          label: 'E-mail',
          controller: _emailController,
          hint: 'voce@exemplo.com',
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          validator: _validateEmail,
        ),
        const SizedBox(height: 20),
        AppFormField(
          label: 'Senha',
          controller: _passwordController,
          hint: 'Sua senha',
          enabled: !_isLoading,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          validator: _validatePassword,
          onFieldSubmitted: (_) => _submit(),
          // A recuperação pertence ao campo de senha, não a uma linha
          // órfã abaixo do formulário.
          trailing: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Esqueci a senha'),
          ),
          suffixIcon: IconButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _FeedbackBanner(message: _errorMessage!, isError: true),
        ],
        if (_infoMessage != null) ...[
          const SizedBox(height: 16),
          _FeedbackBanner(message: _infoMessage!, isError: false),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? Semantics(
                  label: 'Entrando',
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colors.inkFaint,
                    ),
                  ),
                )
              : const Text('Entrar'),
        ),
      ],
    );
  }
}

/// Marca, régua e título.
///
/// A régua abaixo da marca é a única ornamentação da tela, e não é
/// ornamento: é a linha do livro-caixa, o artefato que o produto
/// substitui.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: BrandLockup(),
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: colors.line.withValues(alpha: 0.55)),
        const SizedBox(height: 34),
        Semantics(
          header: true,
          child: Text(
            'Entrar na\nsua Casa',
            style: TextStyle(
              color: colors.ink,
              fontSize: 34,
              height: 1.06,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupPrompt extends StatelessWidget {
  const _SignupPrompt({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ainda não tem conta?',
          style: TextStyle(color: context.colors.inkMuted, fontSize: 14),
        ),
        TextButton(
          onPressed: onPressed,
          child: const Text('Criar conta'),
        ),
      ],
    );
  }
}

/// Aparece uma vez, no carregamento. Nada se move sozinho depois.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, inner) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - curve.value)),
          child: inner,
        ),
      ),
      child: child,
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
    final foreground = isError ? colors.expense : colors.brandInk;
    final background = isError ? colors.expenseSoft : colors.brandSoft;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${isError ? 'Erro: ' : ''}$message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: foreground, width: 3),
            top: BorderSide(color: foreground.withValues(alpha: 0.22)),
            right: BorderSide(color: foreground.withValues(alpha: 0.22)),
            bottom: BorderSide(color: foreground.withValues(alpha: 0.22)),
          ),
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? colors.expense : colors.ink,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
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
