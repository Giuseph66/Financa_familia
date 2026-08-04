import 'package:financa/design_system/components/app_scaffold.dart';
import 'package:financa/design_system/components/money_text.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var _selectedIndex = 0;
  var _privacy = false;
  final _transactions = <_TransactionData>[
    _TransactionData(
      'Mercado do Bairro',
      'Alimentação',
      Icons.shopping_basket_rounded,
      18640,
      false,
      'Hoje, 09:42',
    ),
    _TransactionData(
      'Oficina Central',
      'Transporte',
      Icons.directions_car_filled_rounded,
      42000,
      false,
      'Ontem, 18:20',
    ),
    _TransactionData(
      'Salário',
      'Salário',
      Icons.payments_rounded,
      520000,
      true,
      '01 ago, 08:00',
    ),
    _TransactionData(
      'Netflix',
      'Assinaturas',
      Icons.play_circle_filled_rounded,
      3990,
      false,
      '31 jul, 12:05',
    ),
  ];

  void _openQuickAdd() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(
        onSaved: (cents, category) {
          setState(() {
            _transactions.insert(
              0,
              _TransactionData(
                'Novo lançamento',
                category,
                Icons.receipt_long_rounded,
                cents,
                false,
                'Agora',
              ),
            );
          });
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('Lançamento salvo localmente')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      onQuickAdd: _openQuickAdd,
      body: _selectedIndex == 0
          ? _DashboardContent(
              privacy: _privacy,
              onPrivacyChanged: () => setState(() => _privacy = !_privacy),
              transactions: _transactions,
              onQuickAdd: _openQuickAdd,
            )
          : _PlaceholderContent(
              index: _selectedIndex,
              onQuickAdd: _openQuickAdd,
            ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.privacy,
    required this.onPrivacyChanged,
    required this.transactions,
    required this.onQuickAdd,
  });
  final bool privacy;
  final VoidCallback onPrivacyChanged;
  final List<_TransactionData> transactions;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final maxWidth = wide ? 1180.0 : double.infinity;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            wide ? 42 : 20,
            wide ? 32 : 20,
            wide ? 42 : 20,
            wide ? 42 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onQuickAdd: onQuickAdd),
                  const SizedBox(height: 28),
                  _MonthNavigator(),
                  const SizedBox(height: 16),
                  _HeroBalance(
                    privacy: privacy,
                    onPrivacyChanged: onPrivacyChanged,
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(privacy: privacy),
                  const SizedBox(height: 28),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _ComparisonSection(privacy: privacy)),
                        const SizedBox(width: 18),
                        Expanded(child: _BudgetSection(privacy: privacy)),
                      ],
                    )
                  else ...[
                    _ComparisonSection(privacy: privacy),
                    const SizedBox(height: 18),
                    _BudgetSection(privacy: privacy),
                  ],
                  const SizedBox(height: 28),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _UpcomingSection(privacy: privacy)),
                        const SizedBox(width: 18),
                        Expanded(child: _AccountsSection(privacy: privacy)),
                      ],
                    )
                  else ...[
                    _UpcomingSection(privacy: privacy),
                    const SizedBox(height: 18),
                    _AccountsSection(privacy: privacy),
                  ],
                  const SizedBox(height: 28),
                  _RecentSection(privacy: privacy, transactions: transactions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onQuickAdd});
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 500;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bom dia, Jesus',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 15,
                    color: context.colors.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Casa Neurelix',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tudo salvo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!compact)
          FilledButton.icon(
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova entrada'),
          )
        else
          IconButton.filled(
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nova entrada',
          ),
      ],
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Mês anterior',
              ),
              Text(
                'Agosto 2026',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Casa inteira'),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Mês anterior',
        ),
        Text('Agosto 2026', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Próximo mês',
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('Casa inteira'),
        ),
      ],
    );
  }
}

class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.privacy, required this.onPrivacyChanged});
  final bool privacy;
  final VoidCallback onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.brand,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Saldo do mês',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onPrivacyChanged,
                  tooltip: privacy ? 'Mostrar valores' : 'Esconder valores',
                  icon: Icon(
                    privacy
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoneyText(
              184760,
              privacy: privacy,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 34,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Entradas menos saídas · até hoje',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: 0.68,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '68% do mês transcorrido',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const Spacer(),
                Text(
                  'Dentro do ritmo',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Entradas',
            cents: 680000,
            change: '+12%',
            income: true,
            privacy: privacy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Saídas',
            cents: 495240,
            change: '-4%',
            income: false,
            privacy: privacy,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.cents,
    required this.change,
    required this.income,
    required this.privacy,
  });
  final String label;
  final int cents;
  final String change;
  final bool income;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final color = income ? context.colors.income : context.colors.expense;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: context.colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  income ? Icons.south_west_rounded : Icons.north_east_rounded,
                  size: 17,
                  color: color,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 6),
                  Text(
                    change,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ],
            ),
            if (narrow)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  change,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
            const SizedBox(height: 10),
            MoneyText(
              cents,
              privacy: privacy,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              'vs. média de 3 meses',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Como a casa está andando',
      subtitle: 'Despesas comuns, sem cobrança',
      trailing: TextButton(onPressed: () {}, child: const Text('Detalhes')),
      child: Column(
        children: [
          _MemberBar(
            name: 'Jesus',
            amount: 302000,
            total: 410000,
            color: context.colors.brand,
            privacy: privacy,
          ),
          const SizedBox(height: 16),
          _MemberBar(
            name: 'Maria',
            amount: 222000,
            total: 410000,
            color: context.colors.coral,
            privacy: privacy,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                Icons.handshake_outlined,
                size: 18,
                color: context.colors.inkMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contribuição equilibrada este mês.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberBar extends StatelessWidget {
  const _MemberBar({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
    required this.privacy,
  });
  final String name;
  final int amount;
  final int total;
  final Color color;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final ratio = amount / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text(
                name.substring(0, 1),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(name, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            MoneyText(amount, privacy: privacy, compact: true),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: context.colors.canvas,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Orçamentos em atenção',
      subtitle: 'Só aparece o que pede cuidado',
      child: Column(
        children: [
          _BudgetRow(
            name: 'Mercado',
            spent: 47200,
            limit: 60000,
            privacy: privacy,
          ),
          const SizedBox(height: 18),
          _BudgetRow(
            name: 'Transporte',
            spent: 31000,
            limit: 35000,
            privacy: privacy,
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.name,
    required this.spent,
    required this.limit,
    required this.privacy,
  });
  final String name;
  final int spent;
  final int limit;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final ratio = spent / limit;
    final color = ratio > .85 ? context.colors.warning : context.colors.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            MoneyText(spent, privacy: privacy, compact: true),
            Text(' / ', style: Theme.of(context).textTheme.bodyMedium),
            MoneyText(limit, privacy: privacy, compact: true),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: context.colors.canvas,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Próximas contas',
      subtitle: 'Próximos 7 dias',
      child: Column(
        children: [
          _UpcomingRow(
            name: 'Aluguel',
            date: '05 ago',
            amount: 180000,
            privacy: privacy,
          ),
          const SizedBox(height: 12),
          _UpcomingRow(
            name: 'Internet',
            date: '07 ago',
            amount: 9990,
            privacy: privacy,
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.name,
    required this.date,
    required this.amount,
    required this.privacy,
  });
  final String name;
  final String date;
  final int amount;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.warningSoft,
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 19,
            color: context.colors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.labelLarge),
              Text(
                'vence $date',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        MoneyText(amount, privacy: privacy, compact: true),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: () {}, child: const Text('Pagar')),
      ],
    );
  }
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contas e saldos',
      subtitle: 'Disponível agora',
      child: Row(
        children: [
          Expanded(
            child: _AccountTile(
              name: 'Nubank',
              type: 'Conta corrente',
              amount: 184760,
              color: context.colors.brand,
              privacy: privacy,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AccountTile(
              name: 'Carteira',
              type: 'Dinheiro',
              amount: 32000,
              color: context.colors.lilac,
              privacy: privacy,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.name,
    required this.type,
    required this.amount,
    required this.color,
    required this.privacy,
  });
  final String name;
  final String type;
  final int amount;
  final Color color;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_rounded, size: 18, color: color),
            const SizedBox(height: 14),
            Text(name, style: Theme.of(context).textTheme.labelLarge),
            Text(type, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            MoneyText(amount, privacy: privacy, compact: true),
          ],
        ),
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.privacy, required this.transactions});
  final bool privacy;
  final List<_TransactionData> transactions;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Últimos lançamentos',
      subtitle: 'Atualizado agora',
      trailing: TextButton(onPressed: () {}, child: const Text('Ver tudo')),
      child: Column(
        children: transactions
            .take(5)
            .map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TransactionRow(
                  transaction: transaction,
                  privacy: privacy,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.privacy});
  final _TransactionData transaction;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final color = transaction.income
        ? context.colors.income
        : context.colors.expense;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.all(Radius.circular(13)),
          ),
          child: Icon(transaction.icon, size: 19, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                '${transaction.category} · ${transaction.date}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Text(
          transaction.income ? '+' : '−',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
        const SizedBox(width: 4),
        MoneyText(
          transaction.amount,
          privacy: privacy,
          compact: true,
          color: color,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: context.colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent({required this.index, required this.onQuickAdd});
  final int index;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    const labels = ['Início', 'Extrato', 'Relatórios', 'Mais'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 42,
              color: context.colors.brand,
            ),
            const SizedBox(height: 16),
            Text(
              labels[index],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta área entra na próxima etapa do produto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onQuickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar lançamento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionData {
  const _TransactionData(
    this.name,
    this.category,
    this.icon,
    this.amount,
    this.income,
    this.date,
  );
  final String name;
  final String category;
  final IconData icon;
  final int amount;
  final bool income;
  final String date;
}
