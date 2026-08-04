import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Marca do produto: sinete de livro-caixa + tipo.
///
/// O sinete é a margem vertical de um livro de contas cruzada por duas
/// entradas de comprimentos diferentes. Não é um ícone de carteira nem
/// de cifrão — o produto substitui o caderno onde a casa anota o que
/// entrou e o que saiu, e é esse o artefato que a marca cita.
///
/// Fica dentro de um `Semantics` com rótulo único para o leitor de
/// tela anunciar "Finança" e não descrever as formas.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});

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
          _LedgerSigil(color: colors.brandInk),
          if (!compact) ...[
            const SizedBox(width: 11),
            Text(
              'Finança',
              style: TextStyle(
                color: colors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerSigil extends StatelessWidget {
  const _LedgerSigil({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 19,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Bar(width: 2.5, height: 20, color: color),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(width: 11.5, height: 2.5, color: color),
              const SizedBox(height: 5),
              // A segunda entrada é mais curta e mais fraca: duas
              // linhas iguais leriam como ícone de menu.
              _Bar(
                width: 7,
                height: 2.5,
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
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
