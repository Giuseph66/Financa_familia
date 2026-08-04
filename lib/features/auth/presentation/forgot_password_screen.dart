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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _message = 'Informe um e-mail válido.');
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
        setState(() => _message = 'Enviamos as instruções para seu e-mail.');
      }
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
                Text(
                  'Recuperar acesso',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informe seu e-mail para receber um link de redefinição.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  onSubmitted: (_) => _loading ? null : _send(),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(_message!)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                  Text(
                    'Crie uma nova senha',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escolha uma senha com pelo menos 8 caracteres para proteger sua conta.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _password,
                    enabled: !_loading,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                        ),
                        tooltip: _obscurePassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                      ),
                    ),
                    validator: _validateNewPassword,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmation,
                    enabled: !_loading,
                    obscureText: _obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Confirmar nova senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscureConfirmation
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                      ),
                    ),
                    validator: (value) {
                      if (value != _password.text) {
                        return 'As senhas precisam ser iguais.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _updatePassword(),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(_message!)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _updatePassword,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
