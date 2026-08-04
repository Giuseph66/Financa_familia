import 'dart:typed_data';

import 'package:financa/data/financa_repository.dart';
import 'package:financa/design_system/components/money_text.dart';
import 'package:financa/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class QuickAddDraft {
  const QuickAddDraft({
    required this.kind,
    required this.amountCents,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.memberId,
    this.description,
    this.receiptBytes,
    this.mimeType,
  });

  final String kind;
  final int amountCents;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? memberId;
  final String? description;
  final Uint8List? receiptBytes;
  final String? mimeType;
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({
    this.accounts = const [],
    this.categories = const [],
    this.members = const [],
    this.onSave,
    this.onSuggestCategory,
    this.onCreateCategory,
    super.key,
  }) : assert(onSave != null);

  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final List<HouseholdMember> members;
  final Future<void> Function(QuickAddDraft draft)? onSave;
  final FinanceCategory? Function(
    String description,
    List<FinanceCategory> categories,
  )? onSuggestCategory;
  final Future<FinanceCategory?> Function(
    String name,
    String? parentId,
    String kind,
  )? onCreateCategory;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  static const _maxAmountCents = 99999999999;

  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  late List<FinanceCategory> _categoryOptions;

  var _amountCents = 0;
  var _kind = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _memberId;
  String? _autoCategoryId;
  Uint8List? _receiptBytes;
  String? _receiptName;
  String? _mimeType;
  String? _errorMessage;
  var _categoryWasChosen = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categoryOptions = List<FinanceCategory>.from(widget.categories);
    _accountId = widget.accounts.firstOrNull?.id;
    _memberId = widget.members.firstOrNull?.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  List<FinanceCategory> get _availableCategories {
    if (_kind == 'transfer') return const [];
    final matching = _categoryOptions
        .where(
          (category) =>
              category.kind == _kind ||
              category.kind == 'both' ||
              category.kind == 'all',
        )
        .toList();
    return matching.isEmpty ? _categoryOptions : matching;
  }

  List<FinanceAccount> get _destinationAccounts => widget.accounts
      .where((account) => account.id != _accountId)
      .toList(growable: false);

  void _appendKey(String key) {
    final next = key == '00'
        ? _amountCents * 100
        : _amountCents * 10 + int.parse(key);
    if (next > _maxAmountCents) return;
    setState(() {
      _amountCents = next;
      _errorMessage = null;
    });
  }

  void _removeLastDigit() {
    if (_amountCents == 0) return;
    setState(() {
      _amountCents ~/= 10;
      _errorMessage = null;
    });
  }

  void _selectKind(String kind) {
    setState(() {
      _kind = kind;
      _toAccountId = kind == 'transfer' ? _toAccountId : null;
      if (kind == 'transfer' ||
          (_categoryId != null &&
              !_availableCategories.any((item) => item.id == _categoryId))) {
        _categoryId = null;
        _autoCategoryId = null;
        _categoryWasChosen = false;
      }
      _errorMessage = null;
    });
  }

  void _handleDescriptionChanged(String description) {
    if (_categoryWasChosen) return;
    final suggestion = _suggestCategory(description);
    if (suggestion?.id == _categoryId) return;

    setState(() {
      _categoryId = suggestion?.id;
      _autoCategoryId = suggestion?.id;
    });
  }

  FinanceCategory? _suggestCategory(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty || _kind == 'transfer') return null;

    final callbackSuggestion = widget.onSuggestCategory?.call(
      trimmed,
      _availableCategories,
    );
    if (callbackSuggestion != null) {
      _includeCategoryIfMissing(callbackSuggestion);
      return callbackSuggestion;
    }

    final text = _normalize(trimmed);
    const rules = <String, List<String>>{
      'food': ['mercado', 'supermerc', 'ifood', 'delivery', 'rappi'],
      'transport': ['uber', '99', 'taxi', 'gasolina', 'combust', 'posto'],
      'health': ['farmacia', 'drogasil', 'consulta', 'medico', 'saude'],
      'housing': ['aluguel', 'condominio', 'energia', 'agua', 'luz'],
      'leisure': ['netflix', 'spotify', 'cinema', 'lazer'],
      'income': ['salario', 'folha', 'pagamento', 'freelance'],
    };

    for (final rule in rules.entries) {
      if (!rule.value.any(text.contains)) continue;
      for (final category in _availableCategories) {
        final categoryText = _normalize(category.name);
        final templateKey = _normalize(category.templateKey ?? '');
        if (templateKey.contains(rule.key) ||
            _categoryMatchesRule(categoryText, rule.key)) {
          return category;
        }
      }
    }

    for (final category in _availableCategories) {
      final words = _normalize(category.name)
          .split(' ')
          .where((word) => word.length >= 4);
      if (words.any(text.contains)) return category;
    }
    return null;
  }

  bool _categoryMatchesRule(String category, String rule) {
    const names = <String, List<String>>{
      'food': ['aliment', 'comida', 'mercado', 'refeicao', 'delivery'],
      'transport': ['transport', 'carro', 'combust', 'mobilidade'],
      'health': ['saude', 'farmac', 'medic', 'consulta'],
      'housing': ['casa', 'moradia', 'aluguel', 'conta'],
      'leisure': ['lazer', 'assinatura', 'entretenimento'],
      'income': ['salario', 'renda', 'receita', 'pagamento'],
    };
    return names[rule]?.any(category.contains) ?? false;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  void _includeCategoryIfMissing(FinanceCategory category) {
    if (_categoryOptions.any((item) => item.id == category.id)) return;
    _categoryOptions = [..._categoryOptions, category];
  }

  Future<void> _createCategory() async {
    final callback = widget.onCreateCategory;
    if (callback == null) return;

    final nameController = TextEditingController();
    final parentOptions = _categoryOptions
        .where(
          (category) =>
              category.kind == _kind && category.parentId == null,
        )
        .toList(growable: false);
    var parentId = '';
    final result = await showDialog<_NewCategoryInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nova categoria'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      hintText: 'Ex.: Pets',
                    ),
                  ),
                  if (parentOptions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: parentId.isEmpty ? null : parentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoria principal (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Sem categoria principal'),
                        ),
                        ...parentOptions.map(
                          (category) => DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => parentId = value ?? '',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: nameController.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _NewCategoryInput(
                          nameController.text.trim(),
                          parentId.isEmpty ? null : parentId,
                        ),
                      ),
                child: const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;

    try {
      final category = await callback(result.name, result.parentId, _kind);
      if (!mounted || category == null) return;
      setState(() {
        _includeCategoryIfMissing(category);
        _categoryId = category.id;
        _autoCategoryId = null;
        _categoryWasChosen = true;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(error));
      }
    }
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              subtitle: const Text('Disponível quando a câmera for suportada'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _receiptBytes = bytes;
        _receiptName = file.name;
        _mimeType = file.mimeType ?? _mimeTypeForPath(file.path);
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _friendlyError(error));
    }
  }

  String _mimeTypeForPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Não foi possível concluir a operação.' : message;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final account = _accountId;
    final destination = _toAccountId;
    final memberId = _memberId;

    if (_amountCents <= 0) {
      setState(() => _errorMessage = 'Informe um valor maior que zero.');
      return;
    }
    if (account == null) {
      setState(() => _errorMessage = 'Selecione uma conta.');
      return;
    }
    if (_kind == 'transfer' && destination == null) {
      setState(() => _errorMessage = 'Selecione a conta de destino.');
      return;
    }

    final onSave = widget.onSave;
    if (onSave == null) {
      setState(() => _errorMessage = 'Não foi possível salvar o lançamento.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await onSave(
        QuickAddDraft(
          kind: _kind,
          amountCents: _amountCents,
          accountId: account,
          toAccountId: destination,
          categoryId: _kind == 'transfer' ? null : _categoryId,
          memberId: memberId,
          description: _emptyToNull(_descriptionController.text),
          receiptBytes: _receiptBytes,
          mimeType: _mimeType,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 620;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final borderRadius = wide
        ? BorderRadius.circular(28)
        : const BorderRadius.vertical(top: Radius.circular(28));

    return SafeArea(
      child: Align(
        alignment: wide ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: size.height,
          ),
          child: Material(
            color: context.colors.surface,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Semantics(
                        label: 'Alça do painel',
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.colors.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Entrada rápida',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registre uma movimentação em poucos passos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _KindChip(
                          kind: 'expense',
                          label: 'Despesa',
                          icon: Icons.arrow_upward_rounded,
                          selected: _kind == 'expense',
                          onSelected: _selectKind,
                        ),
                        _KindChip(
                          kind: 'income',
                          label: 'Receita',
                          icon: Icons.arrow_downward_rounded,
                          selected: _kind == 'income',
                          onSelected: _selectKind,
                        ),
                        _KindChip(
                          kind: 'transfer',
                          label: 'Transferência',
                          icon: Icons.swap_horiz_rounded,
                          selected: _kind == 'transfer',
                          onSelected: _selectKind,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Semantics(
                        label: 'Valor ${_amountCents / 100}',
                        liveRegion: true,
                        child: MoneyText(
                          _amountCents,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: constraints.maxWidth < 360 ? 32 : 38, letterSpacing: -1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Keypad(
                      onKey: _appendKey,
                      onBackspace: _removeLastDigit,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 18),
                    _AccountField(
                      label: _kind == 'transfer'
                          ? 'Conta de origem'
                          : 'Conta',
                      value: _accountId,
                      accounts: widget.accounts,
                      enabled: !_isSaving,
                      emptyLabel: 'Nenhuma conta disponível',
                      onChanged: (value) {
                        setState(() {
                          _accountId = value;
                          if (_toAccountId == value) _toAccountId = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                    if (_kind == 'transfer') ...[
                      const SizedBox(height: 12),
                      _AccountField(
                        label: 'Conta de destino',
                        value: _toAccountId,
                        accounts: _destinationAccounts,
                        enabled: !_isSaving,
                        emptyLabel: 'Nenhuma outra conta disponível',
                        onChanged: (value) => setState(() {
                          _toAccountId = value;
                          _errorMessage = null;
                        }),
                      ),
                    ],
                    if (_kind != 'transfer') ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _availableCategories.any(
                                      (item) => item.id == _categoryId,
                                    )
                                    ? _categoryId
                                    : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Categoria',
                                hintText: 'Opcional',
                                helperText: _autoCategoryId != null
                                    ? 'Sugerida pela descrição'
                                    : null,
                              ),
                              items: _availableCategories
                                  .map(
                                    (category) => DropdownMenuItem<String>(
                                      value: category.id,
                                      child: Text(
                                        category.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) => setState(() {
                                      _categoryId = value;
                                      _autoCategoryId = null;
                                      _categoryWasChosen = value != null;
                                    }),
                            ),
                          ),
                          if (widget.onCreateCategory != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isSaving ? null : _createCategory,
                              tooltip: 'Criar categoria',
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _memberId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Membro',
                        hintText: 'Opcional',
                      ),
                      items: widget.members
                          .map(
                            (member) => DropdownMenuItem<String>(
                              value: member.id,
                              child: Text(
                                member.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _memberId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _handleDescriptionChanged,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex.: Mercado do bairro',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReceiptField(
                      bytes: _receiptBytes,
                      name: _receiptName,
                      enabled: !_isSaving,
                      onPick: _pickReceipt,
                      onRemove: () => setState(() {
                        _receiptBytes = null;
                        _receiptName = null;
                        _mimeType = null;
                      }),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _amountCents == 0 || _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Salvando…' : 'Salvar lançamento'),
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
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String kind;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ChoiceChip(
        selected: selected,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => onSelected(kind),
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.value,
    required this.accounts,
    required this.enabled,
    required this.emptyLabel,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<FinanceAccount> accounts;
  final bool enabled;
  final String emptyLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((account) => account.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(accounts.isEmpty ? emptyLabel : 'Selecione'),
      items: accounts
          .map(
            (account) => DropdownMenuItem<String>(
              value: account.id,
              child: Text(account.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled && accounts.isNotEmpty ? onChanged : null,
    );
  }
}

class _ReceiptField extends StatelessWidget {
  const _ReceiptField({
    required this.bytes,
    required this.name,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? name;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return OutlinedButton.icon(
        onPressed: enabled ? onPick : null,
        icon: const Icon(Icons.attach_file_rounded),
        label: const Text('Adicionar comprovante'),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(48),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(14),
        color: context.colors.surfaceRaised,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
                color: context.colors.line,
                child: const Icon(Icons.receipt_long_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name ?? 'Comprovante selecionado',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: enabled ? onRemove : null,
            tooltip: 'Remover comprovante',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onKey,
    required this.onBackspace,
    required this.enabled,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '00'];
    return GridView.builder(
      itemCount: keys.length + 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 52,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index == keys.length) {
          return OutlinedButton(
            onPressed: enabled ? onBackspace : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            child: const Icon(Icons.backspace_outlined),
          );
        }
        final key = keys[index];
        return OutlinedButton(
          onPressed: enabled ? () => onKey(key) : null,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
          ),
          child: Text(key, style: Theme.of(context).textTheme.titleLarge),
        );
      },
    );
  }
}

class _NewCategoryInput {
  const _NewCategoryInput(this.name, this.parentId);

  final String name;
  final String? parentId;
}

extension on List<FinanceAccount> {
  FinanceAccount? get firstOrNull => isEmpty ? null : first;
}

extension on List<HouseholdMember> {
  HouseholdMember? get firstOrNull => isEmpty ? null : first;
}
