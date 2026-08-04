import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/design_system/tokens/radii.dart';
import 'package:financa/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    required this.selectedIndex,
    required this.onSelected,
    required this.onQuickAdd,
    required this.canQuickAdd,
    required this.profileName,
    required this.householdName,
    required this.onHouseholdTap,
    required this.onLogout,
    this.syncLabel = 'Conectado',
    super.key,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onQuickAdd;
  final bool canQuickAdd;
  final String profileName;
  final String householdName;
  final VoidCallback onHouseholdTap;
  final VoidCallback onLogout;
  final String syncLabel;

  static const _items = [
    (Icons.home_rounded, 'Início'),
    (Icons.receipt_long_rounded, 'Extrato'),
    (Icons.bar_chart_rounded, 'Relatórios'),
    (Icons.tune_rounded, 'Mais'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= 920 ? _desktop(context) : _mobile(context),
    );
  }

  Widget _desktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Material(
            color: context.colors.surface,
            child: SafeArea(
              child: SizedBox(
                width: 248,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: AppSpacing.xxl),
                      _WorkspaceButton(
                        name: householdName,
                        onTap: onHouseholdTap,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      for (var index = 0; index < _items.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _RailItem(
                            icon: _items[index].$1,
                            label: _items[index].$2,
                            selected: selectedIndex == index,
                            onTap: () => onSelected(index),
                          ),
                        ),
                      if (canQuickAdd) ...[
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: onQuickAdd,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Novo lançamento'),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 18,
                            color: context.colors.income,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              syncLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Profile(name: profileName, onLogout: onLogout),
                    ],
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, color: context.colors.line),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      floatingActionButton: canQuickAdd
          ? FloatingActionButton(
              onPressed: onQuickAdd,
              tooltip: 'Novo lançamento',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      floatingActionButtonLocation: canQuickAdd
          ? FloatingActionButtonLocation.centerDocked
          : null,
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in _items)
            NavigationDestination(icon: Icon(item.$1), label: item.$2),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.brand,
              borderRadius: AppRadii.small,
            ),
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.home_work_outlined, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Finança', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  const _WorkspaceButton({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cottage_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.unfold_more_rounded, size: 18),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
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
      child: ListTile(
        selected: selected,
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.name, required this.onLogout});
  final String name;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Você' : name.trim();
    return Row(
      children: [
        CircleAvatar(child: Text(displayName[0].toUpperCase())),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onLogout,
          tooltip: 'Sair',
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}
