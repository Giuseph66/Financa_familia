import 'package:financa/design_system/components/money_text.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({required this.onSaved, super.key});

  final void Function(int cents, String category) onSaved;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  var _amountCents = 0;
  var _selectedKind = 'Despesa';
  var _selectedCategory = 'Alimentação';

  static const _categories = [
    (Icons.shopping_basket_rounded, 'Alimentação'),
    (Icons.home_work_rounded, 'Casa'),
    (Icons.directions_car_filled_rounded, 'Transporte'),
    (Icons.favorite_rounded, 'Saúde'),
    (Icons.movie_rounded, 'Lazer'),
  ];

  void _appendDigit(String digit) {
    final next = _amountCents * 10 + int.parse(digit);
    if (next > 99999999999) return;
    setState(() => _amountCents = next);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 620;
    return SafeArea(
      child: Align(
        alignment: wide ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: Material(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Entrada rápida',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Despesa',
                        label: Text('Despesa'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                      ButtonSegment(
                        value: 'Receita',
                        label: Text('Receita'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                      ButtonSegment(
                        value: 'Transferência',
                        label: Text('Transferência'),
                        icon: Icon(Icons.swap_horiz_rounded),
                      ),
                    ],
                    selected: {_selectedKind},
                    onSelectionChanged: (value) =>
                        setState(() => _selectedKind = value.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: MoneyText(
                      _amountCents,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 38, letterSpacing: -1.5),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Categoria',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final selected = _selectedCategory == category.$2;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(category.$2),
                        avatar: Icon(category.$1, size: 17),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category.$2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _QuickChip(
                        icon: Icons.account_balance_rounded,
                        label: 'Nubank',
                      ),
                      _QuickChip(icon: Icons.today_rounded, label: 'Hoje'),
                      _QuickChip(icon: Icons.person_rounded, label: 'Você'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Keypad(
                    onDigit: _appendDigit,
                    onBackspace: () => setState(() => _amountCents ~/= 10),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _amountCents == 0
                        ? null
                        : () {
                            widget.onSaved(_amountCents, _selectedCategory);
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Salvar lançamento'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: context.colors.inkMuted),
      label: Text(label),
      side: BorderSide(color: context.colors.line),
      backgroundColor: context.colors.surfaceRaised,
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '00'];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...keys.map(
          (key) => OutlinedButton(
            onPressed: key == ',' ? null : () => onDigit(key),
            child: Text(key, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        OutlinedButton(
          onPressed: onBackspace,
          child: const Icon(Icons.backspace_outlined),
        ),
      ],
    );
  }
}
