import 'dart:math' as math;

import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';

/// Ilustração do topo das telas de autenticação.
///
/// Vetor montado em widgets, não imagem: acompanha o tema, não pesa no
/// bundle e escala sem borrar. Paleta do app, sem brilho 3D.
///
/// A cena é desenhada numa base fixa de 278x196 e escalada inteira por
/// um [FittedBox], então as posições nunca se desmancham em tela
/// estreita — é o que permite usar coordenadas absolutas com segurança.
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, this.height = 190});

  final double height;

  static const _baseW = 278.0;
  static const _baseH = 196.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: height * (_baseW / _baseH),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _baseW,
            height: _baseH,
            child: Stack(
              children: [
                // Mancha que agrupa a cena e a separa do canvas.
                Positioned(
                  left: 28,
                  top: 10,
                  child: Container(
                    width: 222,
                    height: 176,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(118, 96),
                      ),
                    ),
                  ),
                ),

                _Sparkle(left: 14, top: 54, color: colors.brandInk),
                _Sparkle(left: 258, top: 92, color: colors.income),

                // Cédulas: atrás da carteira, espiando por cima dela.
                Positioned(
                  left: 74,
                  top: 58,
                  child: Transform.rotate(
                    angle: -0.08,
                    child: _Note(colors: colors),
                  ),
                ),

                // Cartão com barras.
                Positioned(
                  left: 176,
                  top: 16,
                  child: _ChartCard(colors: colors),
                ),

                // Carteira.
                Positioned(
                  left: 62,
                  top: 88,
                  child: _Wallet(colors: colors),
                ),

                // Moedas, à frente da carteira.
                Positioned(
                  left: 8,
                  top: 118,
                  child: _Coins(colors: colors),
                ),

                // Rosca de categorias.
                Positioned(
                  left: 196,
                  top: 108,
                  child: _Donut(colors: colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 46,
      decoration: BoxDecoration(
        color: colors.income.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.canvas.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _Wallet extends StatelessWidget {
  const _Wallet({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 80,
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          // Aba com o fecho.
          Positioned(
            right: 0,
            top: 24,
            child: Container(
              width: 46,
              height: 34,
              decoration: BoxDecoration(
                color: colors.canvas.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 78,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Bar(height: 18, color: colors.brandInk.withValues(alpha: 0.5)),
          _Bar(height: 32, color: colors.brand),
          _Bar(height: 48, color: colors.income),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _Coins extends StatelessWidget {
  const _Coins({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 56,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 2,
              top: 30.0 - i * 8,
              child: Container(
                width: 40,
                height: 14,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.4 + i * 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          Positioned(
            left: 22,
            top: 20,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.warning,
              ),
              alignment: Alignment.center,
              child: Text(
                r'R$',
                style: TextStyle(
                  color: colors.canvas,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceRaised,
        border: Border.all(color: colors.line.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(38, 38),
          painter: _DonutPainter(
            segments: [
              (0.46, colors.brand),
              (0.31, colors.income),
              (0.23, colors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});

  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(4);
    var start = -math.pi / 2;

    for (final (fraction, color) in segments) {
      final sweep = fraction * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        // Folga entre fatias para o limite ler sem depender só de cor.
        sweep - 0.1,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.left,
    required this.top,
    required this.color,
  });

  final double left;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Icon(
        Icons.add_rounded,
        size: 12,
        color: color.withValues(alpha: 0.55),
      ),
    );
  }
}
