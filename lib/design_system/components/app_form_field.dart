import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Campo com rótulo fixo acima da caixa.
///
/// Não usa o rótulo flutuante do Material de propósito. O rótulo
/// flutuante encolhe e se sobrepõe à borda quando o campo recebe
/// conteúdo, e some do alcance de quem usa ampliação de tela — quem
/// mais precisa dele é quem primeiro o perde. Aqui o rótulo fica onde
/// está, no mesmo tamanho, o tempo todo.
class AppFormField extends StatelessWidget {
  const AppFormField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.prefixIcon,
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
  final IconData? prefixIcon;
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
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
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
            color: colors.ink,
            // 16px é o piso: abaixo disso o Safari no iOS dá zoom
            // automático ao focar o campo e desloca o layout inteiro.
            fontSize: 16,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(prefixIcon, size: 20),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: suffixIcon,
            // O rótulo já está acima; nada deve flutuar para dentro.
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
        ),
      ],
    );
  }
}
