import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum BrandSize {
  /// Barras de app e cabeçalhos internos.
  regular(sigil: 20, text: 17, gap: 11),

  /// Topo das telas de autenticação.
  large(sigil: 32, text: 28, gap: 14);

  const BrandSize({required this.sigil, required this.text, required this.gap});

  final double sigil;
  final double text;
  final double gap;
}

/// Marca do produto: sinete de livro-caixa + tipo.
///
/// O sinete é a margem vertical de um livro de contas cruzada por duas
/// entradas de comprimentos diferentes. Não é ícone de carteira nem de
/// cifrão — o produto substitui o caderno onde a casa anota o que
/// entrou e o que saiu, e é esse o artefato que a marca cita.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.size = BrandSize.regular,
    this.compact = false,
  });

  final BrandSize size;

  /// Só o sinete, sem o tipo. Para barras estreitas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: 'Finança',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LedgerSigil(color: colors.brandInk, extent: size.sigil),
          if (!compact) ...[
            SizedBox(width: size.gap),
            Text(
              'Finança',
              style: TextStyle(
                color: colors.ink,
                fontSize: size.text,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerSigil extends StatelessWidget {
  const _LedgerSigil({required this.color, required this.extent});

  final Color color;
  final double extent;

  @override
  Widget build(BuildContext context) {
    // Tudo proporcional ao lado, para o sinete crescer sem se deformar.
    final stroke = extent * 0.13;
    final gap = extent * 0.25;

    return SizedBox(
      width: extent * 0.95,
      height: extent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Bar(width: stroke, height: extent, color: color),
          SizedBox(width: gap),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(width: extent * 0.58, height: stroke, color: color),
              SizedBox(height: gap),
              // A segunda entrada é mais curta e mais fraca: duas
              // linhas iguais leriam como ícone de menu.
              _Bar(
                width: extent * 0.35,
                height: stroke,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height.clamp(1, 4)),
      ),
    );
  }
}
