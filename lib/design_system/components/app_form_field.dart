import 'package:flutter/material.dart';

/// Campo com rótulo persistente acima da caixa, em caixa alta.
///
/// Não usa o rótulo flutuante do Material de propósito. O rótulo
/// flutuante encolhe e se sobrepõe à borda quando o campo recebe
/// conteúdo, e some do alcance de quem usa ampliação de tela — quem
/// mais precisa dele é quem primeiro o perde. Aqui o rótulo fica onde
/// está, no mesmo tamanho, o tempo todo.
///
/// O preenchimento e a borda vêm do `inputDecorationTheme`, então o
/// campo é escavado no canvas em vez de apoiado sobre ele.
class AppFormField extends StatelessWidget {
  const AppFormField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.trailing,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Ação secundária alinhada à direita, na mesma linha do rótulo.
  /// Usada para "Esqueci a senha", que pertence ao campo de senha e
  /// não a uma linha solta abaixo do formulário.
  final Widget? trailing;

  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            // 16px é o piso: abaixo disso o Safari no iOS dá zoom
            // automático ao focar o campo e desloca o layout inteiro.
            fontSize: 16,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            // O rótulo já está acima; nada deve flutuar para dentro.
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
        ),
      ],
    );
  }
}
