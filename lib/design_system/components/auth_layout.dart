import 'package:financa/design_system/components/brand_lockup.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Moldura comum das telas de autenticação.
///
/// Sem card e sem gradiente: em tela cheia de celular o card é chrome
/// redundante — a tela já é o recipiente. Centraliza, limita a largura
/// de leitura e rola quando o teclado sobe.
class AuthShell extends StatelessWidget {
  const AuthShell({required this.children, super.key, this.showBrand = true});

  final List<Widget> children;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: ConstrainedBox(
              // Trava a largura para a linha de leitura não esticar em
              // tablet. Só-mobile na intenção, íntegro em tela larga.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBrand) ...[
                    const Center(child: BrandLockup(size: BrandSize.large)),
                    const SizedBox(height: 20),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título e apoio centralizados, no topo do formulário.
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({required this.title, super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.inkMuted,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, this.label = 'ou'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rule = Expanded(
      child: Container(height: 1, color: colors.line.withValues(alpha: 0.65)),
    );

    return ExcludeSemantics(
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              style: TextStyle(color: colors.inkMuted, fontSize: 14),
            ),
          ),
          rule,
        ],
      ),
    );
  }
}

/// Retorno de erro ou confirmação.
///
/// `liveRegion` para o leitor de tela anunciar assim que aparece: quem
/// não vê a tela precisa saber que a tentativa falhou sem ir procurar.
class AuthFeedbackBanner extends StatelessWidget {
  const AuthFeedbackBanner({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = isError ? colors.expense : colors.brandInk;
    final background = isError ? colors.expenseSoft : colors.brandSoft;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${isError ? 'Erro: ' : ''}$message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
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
                color: accent,
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

/// Pergunta + ação de troca de tela, centralizada no rodapé.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.question,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: TextStyle(color: context.colors.inkMuted, fontSize: 14),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
