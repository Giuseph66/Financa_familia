import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.compact = false,
    this.privacy = false,
    this.color,
  });

  final int cents;
  final TextStyle? style;
  final bool compact;
  final bool privacy;
  final Color? color;

  static final _format = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final value = privacy ? 'R\$ ••••' : _format.format(cents / 100);
    final defaultStyle = compact
        ? Theme.of(context).textTheme.labelLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Text(
      value,
      style: (style ?? defaultStyle)?.copyWith(
        color: color ?? style?.color ?? context.colors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
