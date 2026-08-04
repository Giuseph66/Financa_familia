import 'package:financa/design_system/tokens/app_colors.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    required this.selectedIndex,
    required this.onSelected,
    required this.onQuickAdd,
    super.key,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onQuickAdd;

  static const _items = [
    (Icons.grid_view_rounded, 'Início'),
    (Icons.receipt_long_rounded, 'Extrato'),
    (Icons.insights_rounded, 'Relatórios'),
    (Icons.more_horiz_rounded, 'Mais'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 960) return _desktopLayout(context);
        return _mobileLayout(context);
      },
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 232,
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(right: BorderSide(color: context.colors.line)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandMark(colors: context.colors),
                    const SizedBox(height: 44),
                    for (var i = 0; i < _items.length; i++) ...[
                      _NavItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        selected: selectedIndex == i,
                        onTap: () => onSelected(i),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Spacer(),
                    _SyncIndicator(colors: context.colors),
                    const SizedBox(height: 16),
                    const _ProfileTile(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton(
        onPressed: onQuickAdd,
        tooltip: 'Nova entrada',
        backgroundColor: context.colors.brand,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: context.colors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i == 2) const SizedBox(width: 56),
              _BottomNavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.brand,
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
          child: const Icon(
            Icons.stacked_line_chart_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text('Finança', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? context.colors.brandSoft : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? context.colors.brand
                    : context.colors.inkMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? context.colors.brand
                      : context.colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? context.colors.brand : context.colors.inkMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? context.colors.brand
                    : context.colors.inkMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_done_rounded, size: 17, color: colors.brand),
        const SizedBox(width: 8),
        Text(
          'Tudo salvo localmente',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: context.colors.brandSoft,
          child: Text(
            'J',
            style: TextStyle(
              color: context.colors.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jesus', style: Theme.of(context).textTheme.labelLarge),
              Text(
                'Casa Neurelix',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Icon(Icons.more_horiz_rounded, color: context.colors.inkFaint),
      ],
    );
  }
}
