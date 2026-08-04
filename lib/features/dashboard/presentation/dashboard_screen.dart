import 'dart:async';

import 'package:financa/data/financa_repository.dart';
import 'package:financa/design_system/components/app_scaffold.dart';
import 'package:financa/design_system/components/money_text.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:financa/design_system/tokens/radii.dart';
import 'package:financa/design_system/tokens/spacing.dart';
import 'package:financa/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = FinancaRepository();
  FinancaSnapshot? _snapshot;
  Object? _error;
  var _loading = true;
  var _tab = 0;
  var _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _memberScope;
  var _privateValues = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({String? householdId}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.load(householdId: householdId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _memberScope = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _selectHousehold() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: snapshot.selectedHousehold.id,
          onChanged: (value) => Navigator.pop(context, value),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Trocar Casa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final household in snapshot.households)
                RadioListTile<String>(
                  value: household.id,
                  title: Text(household.name),
                  subtitle: Text(
                    household.id == snapshot.selectedHousehold.id
                        ? 'Casa atual'
                        : 'Abrir este workspace',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != snapshot.selectedHousehold.id) {
      await _reload(householdId: selected);
    }
  }

  Future<void> _selectScope() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: _memberScope ?? 'all',
          onChanged: (value) => Navigator.pop(context, value),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Visão da Casa'),
                subtitle: Text(
                  'Filtre sem alterar quem pode ver ou editar os dados.',
                ),
              ),
              RadioListTile<String>(
                value: 'all',
                title: const Text('Casa inteira'),
                secondary: const Icon(Icons.groups_2_outlined),
              ),
              for (final member in snapshot.memberships)
                RadioListTile<String>(
                  value: member.id,
                  title: Text(_displayName(member.displayName)),
                  subtitle: Text(_roleLabel(member.role)),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      if (!mounted) return;
      setState(() => _memberScope = selected == 'all' ? null : selected);
    }
  }

  Future<void> _openQuickAdd() async {
    final snapshot = _snapshot;
    if (snapshot == null || !_canQuickAdd(snapshot)) return;
    if (snapshot.accounts.isEmpty) {
      _message('Crie uma conta antes de lançar.');
      return;
    }
    final currentMember = _memberForCurrentUser(snapshot);
    final isTeen = currentMember?.role == 'teen';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(
        accounts: snapshot.accounts,
        categories: snapshot.categories,
        members: isTeen && currentMember != null
            ? [currentMember]
            : snapshot.memberships,
        onSave: _saveDraft,
        onCreateCategory: _canCreateCategory(snapshot) ? _createCategory : null,
      ),
    );
  }

  Future<FinanceCategory?> _createCategory(
    String name,
    String? parentId,
    String kind,
  ) async {
    final snapshot = _snapshot;
    if (snapshot == null || !_canCreateCategory(snapshot)) return null;
    try {
      return await _repository.createCategory(
        householdId: snapshot.selectedHousehold.id,
        name: name,
        parentId: parentId,
        kind: kind,
      );
    } catch (_) {
      throw StateError('Não foi possível criar a categoria.');
    }
  }

  Future<void> _saveDraft(QuickAddDraft draft) async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      throw StateError('Não foi possível salvar: a Casa não está disponível.');
    }
    final currentMember = _memberForCurrentUser(snapshot);
    if (!_canQuickAdd(snapshot) || currentMember == null) {
      throw StateError('Seu papel não permite criar lançamentos.');
    }
    final memberId = draft.memberId;
    if (memberId == null) {
      throw StateError('Selecione um membro antes de salvar.');
    }
    if (currentMember.role == 'teen' && memberId != currentMember.id) {
      throw StateError('Você só pode lançar em seu próprio nome.');
    }
    if (currentMember.role == 'teen' && draft.receiptBytes != null) {
      throw StateError('Seu papel não permite adicionar comprovantes.');
    }
    final toAccountId = draft.toAccountId;
    if (draft.kind == 'transfer' && toAccountId == null) {
      throw StateError('Selecione a conta de destino antes de salvar.');
    }

    try {
      String? receiptId;
      final receiptBytes = draft.receiptBytes;
      if (receiptBytes != null) {
        final receipt = await _repository.uploadReceipt(
          householdId: snapshot.selectedHousehold.id,
          bytes: receiptBytes,
          mimeType: draft.mimeType ?? 'image/jpeg',
        );
        receiptId = receipt.id;
      }
      if (draft.kind == 'transfer') {
        final transferAccountId = draft.toAccountId;
        if (transferAccountId == null) {
          throw StateError('Selecione a conta de destino antes de salvar.');
        }
        await _repository.createTransfer(
          householdId: snapshot.selectedHousehold.id,
          fromAccountId: draft.accountId,
          toAccountId: transferAccountId,
          memberId: memberId,
          amountCents: draft.amountCents,
          description: draft.description,
        );
      } else {
        await _repository.createTransaction(
          householdId: snapshot.selectedHousehold.id,
          accountId: draft.accountId,
          memberId: memberId,
          amountCents: draft.amountCents,
          kind: draft.kind,
          categoryId: draft.categoryId,
          description: draft.description,
          receiptId: receiptId,
        );
      }
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('Não foi possível salvar o lançamento.');
    }
    await _reload(householdId: snapshot.selectedHousehold.id);
    _message(
      'Lançamento salvo.',
      action: 'Ver extrato',
      onAction: () => _selectTab(1),
    );
  }

  void _selectTab(int value) {
    if (!mounted) return;
    setState(() => _tab = value);
  }

  void _changeMonth(int offset) {
    if (!mounted) return;
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  void _togglePrivacy() {
    if (!mounted) return;
    setState(() => _privateValues = !_privateValues);
  }

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    try {
      await _repository.softDeleteTransaction(transaction.id);
      await _reload(householdId: transaction.householdId);
      _message(
        'Lançamento removido.',
        action: 'Desfazer',
        onAction: () => _restoreTransaction(transaction),
      );
    } catch (_) {
      _message('Não foi possível remover o lançamento.');
    }
  }

  Future<void> _restoreTransaction(FinanceTransaction transaction) async {
    try {
      await _repository.restoreTransaction(transaction.id);
      await _reload(householdId: transaction.householdId);
      _message('Lançamento restaurado.');
    } catch (_) {
      _message('Não foi possível desfazer a remoção.');
    }
  }

  Future<void> _duplicateTransaction(FinanceTransaction transaction) async {
    try {
      await _repository.duplicateTransaction(transaction);
      await _reload(householdId: transaction.householdId);
      _message('Lançamento duplicado.');
    } catch (_) {
      _message('Não foi possível duplicar o lançamento.');
    }
  }

  bool _canQuickAdd(FinancaSnapshot snapshot) {
    final role = _memberForCurrentUser(snapshot)?.role;
    return role == 'owner' || role == 'adult' || role == 'teen';
  }

  bool _canCreateCategory(FinancaSnapshot snapshot) {
    final role = _memberForCurrentUser(snapshot)?.role;
    return role == 'owner' || role == 'adult';
  }

  bool _canModifyTransaction(
    FinancaSnapshot snapshot,
    FinanceTransaction transaction,
  ) {
    final member = _memberForCurrentUser(snapshot);
    if (member?.role == 'owner' || member?.role == 'adult') return true;
    return member?.role == 'teen' && transaction.memberId == member?.id;
  }

  void _message(String text, {String? action, VoidCallback? onAction}) {
    if (!mounted) return;
    final snackAction = action == null || onAction == null
        ? null
        : SnackBarAction(label: action, onPressed: onAction);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), action: snackAction));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_loading && snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final error = _error;
    if (error != null && snapshot == null) {
      return _ErrorScreen(error: error, onRetry: _reload);
    }
    if (snapshot == null) return const SizedBox.shrink();

    final body = switch (_tab) {
      0 => _OverviewTab(
        snapshot: snapshot,
        month: _month,
        memberScope: _memberScope,
        privateValues: _privateValues,
        onPreviousMonth: () => _changeMonth(-1),
        onNextMonth: () => _changeMonth(1),
        onScope: _selectScope,
        onTogglePrivacy: _togglePrivacy,
        onRefresh: () => _reload(householdId: snapshot.selectedHousehold.id),
        onOpenTransactions: () => _selectTab(1),
      ),
      1 => _TransactionsTab(
        snapshot: snapshot,
        memberScope: _memberScope,
        onScope: _selectScope,
        canModify: (transaction) =>
            _canModifyTransaction(snapshot, transaction),
        onDelete: _deleteTransaction,
        onDuplicate: _duplicateTransaction,
      ),
      2 => _ReportsTab(
        snapshot: snapshot,
        month: _month,
        memberScope: _memberScope,
      ),
      _ => _MoreTab(
        snapshot: snapshot,
        repository: _repository,
        onChanged: () => _reload(householdId: snapshot.selectedHousehold.id),
      ),
    };

    return AppScaffold(
      selectedIndex: _tab,
      onSelected: _selectTab,
      onQuickAdd: _openQuickAdd,
      canQuickAdd: _canQuickAdd(snapshot),
      profileName: _displayName(snapshot.profile.displayName, fallback: 'Você'),
      householdName: snapshot.selectedHousehold.name,
      onHouseholdTap: _selectHousehold,
      onLogout: () => Supabase.instance.client.auth.signOut(),
      syncLabel: _loading ? 'Sincronizando…' : 'Sincronizado agora',
      body: body,
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snapshot,
    required this.month,
    required this.memberScope,
    required this.privateValues,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onScope,
    required this.onTogglePrivacy,
    required this.onRefresh,
    required this.onOpenTransactions,
  });
  final FinancaSnapshot snapshot;
  final DateTime month;
  final String? memberScope;
  final bool privateValues;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onScope;
  final VoidCallback onTogglePrivacy;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final transactions = snapshot.transactions.where((item) {
      return item.occurredAt.year == month.year &&
          item.occurredAt.month == month.month &&
          (memberScope == null || item.memberId == memberScope);
    }).toList();
    final income = transactions
        .where((item) => item.kind == 'income')
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final expense = transactions
        .where((item) => item.kind == 'expense')
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final scopedMember = memberScope == null
        ? null
        : snapshot.memberships
              .where((item) => item.id == memberScope)
              .firstOrNull;
    final scopeName = memberScope == null
        ? 'Casa inteira'
        : _displayName(scopedMember?.displayName, fallback: 'Membro');
    final comparisonMembers = memberScope == null
        ? snapshot.memberships
        : snapshot.memberships
              .where((member) => member.id == memberScope)
              .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PageHeader(
              eyebrow: snapshot.selectedHousehold.name,
              title:
                  'Olá, ${_displayName(snapshot.profile.displayName, fallback: 'Você')}',
              subtitle: 'Uma visão clara do que aconteceu, sem julgamento.',
              trailing: IconButton(
                onPressed: onTogglePrivacy,
                tooltip: privateValues ? 'Mostrar valores' : 'Ocultar valores',
                icon: Icon(
                  privateValues
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              100,
            ),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      onPressed: onPreviousMonth,
                      tooltip: 'Mês anterior',
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      _monthLabel(month),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      onPressed: onNextMonth,
                      tooltip: 'Próximo mês',
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    OutlinedButton.icon(
                      onPressed: onScope,
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: Text(scopeName),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _BalanceStrip(
                  balance: income - expense,
                  income: income,
                  expense: expense,
                  hidden: privateValues,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(
                  title: memberScope == null
                      ? 'Contribuições da Casa'
                      : 'Movimento de $scopeName',
                  subtitle: 'Valores factuais do mês selecionado.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (transactions.isEmpty)
                  const _EmptyState(
                    icon: Icons.edit_note_rounded,
                    title: 'Nenhum lançamento neste recorte',
                    description:
                        'Use o botão + para registrar a primeira movimentação.',
                  )
                else
                  _MemberComparison(
                    members: comparisonMembers,
                    transactions: transactions,
                    hidden: privateValues,
                  ),
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(
                  title: 'Últimos lançamentos',
                  action: TextButton(
                    onPressed: onOpenTransactions,
                    child: const Text('Abrir extrato'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in transactions.take(5))
                  _TransactionTile(
                    transaction: item,
                    snapshot: snapshot,
                    hidden: privateValues,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.snapshot,
    required this.memberScope,
    required this.canModify,
    required this.onScope,
    required this.onDelete,
    required this.onDuplicate,
  });
  final FinancaSnapshot snapshot;
  final String? memberScope;
  final bool Function(FinanceTransaction transaction) canModify;
  final VoidCallback onScope;
  final Future<void> Function(FinanceTransaction transaction) onDelete;
  final Future<void> Function(FinanceTransaction transaction) onDuplicate;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.transactions
        .where((item) => memberScope == null || item.memberId == memberScope)
        .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _PageHeader(
            eyebrow: snapshot.selectedHousehold.name,
            title: 'Extrato',
            subtitle: 'Entradas, saídas e transferências em ordem.',
            trailing: IconButton(
              onPressed: onScope,
              tooltip: 'Filtrar por membro',
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Seu extrato está vazio',
              description: 'O primeiro lançamento aparecerá aqui.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              100,
            ),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (!canModify(item)) {
                  return _TransactionTile(
                    transaction: item,
                    snapshot: snapshot,
                    hidden: false,
                  );
                }
                return Dismissible(
                  key: ValueKey(item.id),
                  background: const _SwipeAction(
                    alignment: Alignment.centerLeft,
                    icon: Icons.copy_rounded,
                    label: 'Duplicar',
                  ),
                  secondaryBackground: const _SwipeAction(
                    alignment: Alignment.centerRight,
                    icon: Icons.delete_outline_rounded,
                    label: 'Remover',
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await onDuplicate(item);
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (_) => unawaited(onDelete(item)),
                  child: _TransactionTile(
                    transaction: item,
                    snapshot: snapshot,
                    hidden: false,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.snapshot,
    required this.month,
    required this.memberScope,
  });
  final FinancaSnapshot snapshot;
  final DateTime month;
  final String? memberScope;

  @override
  Widget build(BuildContext context) {
    final expenses = <String, int>{};
    for (final transaction in snapshot.transactions) {
      if (transaction.kind != 'expense' ||
          transaction.occurredAt.year != month.year ||
          transaction.occurredAt.month != month.month ||
          (memberScope != null && transaction.memberId != memberScope)) {
        continue;
      }
      expenses.update(
        transaction.memberId,
        (value) => value + transaction.amountCents,
        ifAbsent: () => transaction.amountCents,
      );
    }
    final total = expenses.values.fold<int>(0, (sum, value) => sum + value);
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const _PageHeader(
          eyebrow: 'Comparativo',
          title: 'Como a Casa contribuiu',
          subtitle: 'Só fatos. A divisão ideal é uma decisão de vocês.',
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              if (total == 0)
                const _EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Ainda não há dados para comparar',
                  description:
                      'As despesas compartilhadas formarão este relatório.',
                )
              else
                for (final member in snapshot.memberships.where(
                  (member) => memberScope == null || member.id == memberScope,
                ))
                  _ContributionRow(
                    name: _displayName(member.displayName),
                    cents: expenses[member.id] ?? 0,
                    total: total,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreTab extends StatefulWidget {
  const _MoreTab({
    required this.snapshot,
    required this.repository,
    required this.onChanged,
  });
  final FinancaSnapshot snapshot;
  final FinancaRepository repository;
  final Future<void> Function() onChanged;
  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  Future<void> _invite() async {
    final currentMember = _memberForCurrentUser(widget.snapshot);
    if (currentMember?.role != 'owner') return;
    try {
      final code = await widget.repository.createInvite(
        widget.snapshot.selectedHousehold.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de convite'),
          content: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Concluir'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showMessage('Não foi possível criar o convite.');
    }
  }

  Future<void> _redeem() async {
    if (!mounted) return;
    var draftCode = '';
    final parentContext = context;
    String? code;
    try {
      code = await showDialog<String>(
        context: parentContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Entrar em uma Casa'),
          content: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) => draftCode = value,
            decoration: const InputDecoration(labelText: 'Código do convite'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftCode),
              child: const Text('Entrar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível abrir o convite.');
      return;
    }
    if (!mounted || code == null || code.trim().isEmpty) return;

    try {
      await widget.repository.redeemInvite(code);
      if (!mounted) return;
      await widget.onChanged();
      if (!mounted) return;
      _showMessage('Você entrou na Casa.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível usar esse convite.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser?.id;
    final currentMember = _memberForCurrentUser(widget.snapshot);
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _PageHeader(
          eyebrow: widget.snapshot.selectedHousehold.name,
          title: 'Casa e preferências',
          subtitle: 'Pessoas, papéis e acesso ao workspace.',
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pessoas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              for (final member in widget.snapshot.memberships)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      _displayName(member.displayName)[0].toUpperCase(),
                    ),
                  ),
                  title: Text(_displayName(member.displayName)),
                  subtitle: Text(_roleLabel(member.role)),
                  trailing: member.userId == currentUser
                      ? const Chip(label: Text('Você'))
                      : null,
                ),
              const SizedBox(height: AppSpacing.lg),
              if (currentMember?.role == 'owner')
                FilledButton.icon(
                  onPressed: _invite,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Convidar pessoa'),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _redeem,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Usar código de convite'),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({
    required this.balance,
    required this.income,
    required this.expense,
    required this.hidden,
  });
  final int balance;
  final int income;
  final int expense;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.line),
        borderRadius: AppRadii.medium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.lg,
          children: [
            _Metric(label: 'Saldo do mês', cents: balance, hidden: hidden),
            _Metric(label: 'Entradas', cents: income, hidden: hidden),
            _Metric(label: 'Saídas', cents: -expense, hidden: hidden),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.cents,
    required this.hidden,
  });
  final String label;
  final int cents;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hidden ? '$label oculto' : label,
      child: SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            if (hidden)
              Text('••••••', style: Theme.of(context).textTheme.headlineSmall)
            else
              MoneyText(
                cents,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberComparison extends StatelessWidget {
  const _MemberComparison({
    required this.members,
    required this.transactions,
    required this.hidden,
  });
  final List<HouseholdMember> members;
  final List<FinanceTransaction> transactions;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final item in transactions.where((item) => item.kind == 'expense')) {
      totals.update(
        item.memberId,
        (value) => value + item.amountCents,
        ifAbsent: () => item.amountCents,
      );
    }
    final max = totals.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final member in members)
          Semantics(
            label:
                '${_displayName(member.displayName)}, ${((totals[member.id] ?? 0) / max * 100).round()} por cento da maior contribuição',
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(_displayName(member.displayName)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (totals[member.id] ?? 0) / max,
                      minHeight: 10,
                      borderRadius: AppRadii.pill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 100,
                    child: hidden
                        ? const Text('••••')
                        : MoneyText(-(totals[member.id] ?? 0)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.snapshot,
    required this.hidden,
  });
  final FinanceTransaction transaction;
  final FinancaSnapshot snapshot;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final category = snapshot.categories
        .where((item) => item.id == transaction.categoryId)
        .firstOrNull;
    final member = snapshot.memberships
        .where((item) => item.id == transaction.memberId)
        .firstOrNull;
    final income = transaction.kind == 'income';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: income
            ? context.colors.incomeSoft
            : context.colors.expenseSoft,
        child: Icon(
          income ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: income ? context.colors.income : context.colors.expense,
        ),
      ),
      title: Text(transaction.description ?? category?.name ?? 'Sem descrição'),
      subtitle: Text(
        '${_displayName(member?.displayName, fallback: 'Casa')} · ${_dateLabel(transaction.occurredAt)}'
        '${transaction.receiptId == null ? '' : ' · recibo'}',
      ),
      trailing: hidden
          ? const Text('••••')
          : MoneyText(transaction.signedAmountCents),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.name,
    required this.cents,
    required this.total,
  });
  final String name;
  final int cents;
  final int total;
  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0.0 : cents / total;
    return Semantics(
      label: '$name, ${(percentage * 100).round()} por cento das despesas',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name)),
                MoneyText(-cents),
                const SizedBox(width: AppSpacing.sm),
                Text('${(percentage * 100).round()}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              borderRadius: AppRadii.pill,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final subtitleWidget = subtitleText == null ? null : Text(subtitleText);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ?subtitleWidget,
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: context.colors.inkFaint),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.icon,
    required this.label,
  });
  final Alignment alignment;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      color: context.colors.surfaceRaised,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function({String? householdId}) onRetry;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        description: '$error',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => onRetry(),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}

HouseholdMember? _memberForCurrentUser(FinancaSnapshot snapshot) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  return snapshot.memberships
      .where((item) => item.userId == userId)
      .firstOrNull;
}

String _displayName(String? value, {String fallback = 'Membro'}) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _monthLabel(DateTime date) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${months[date.month - 1]} de ${date.year}';
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _roleLabel(String role) => switch (role) {
  'owner' => 'Dono da Casa',
  'teen' => 'Adolescente',
  'viewer' => 'Somente leitura',
  _ => 'Adulto',
};
