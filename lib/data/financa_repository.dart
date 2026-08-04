import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class FinancaRepository {
  FinancaRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');
    return user;
  }

  Future<List<Map<String, dynamic>>> _loadAllTransactions(
    String householdId,
  ) async {
    const pageSize = 1000;
    final transactions = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final rows = await _client
          .from('transactions')
          .select()
          .eq('household_id', householdId)
          .isFilter('deleted_at', null)
          .order('occurred_at', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);
      final page = (rows as List).cast<Map<String, dynamic>>();
      transactions.addAll(page);
      if (page.length < pageSize) return transactions;
    }
  }

  Future<FinancaSnapshot> load({String? householdId}) async {
    final user = _user;
    final profileMap = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final membershipMaps = await _client
        .from('household_members')
        .select()
        .eq('user_id', user.id)
        .isFilter('deleted_at', null);
    final memberships = membershipMaps
        .map(HouseholdMember.fromMap)
        .toList(growable: false);
    if (memberships.isEmpty) {
      throw StateError('Sua conta ainda não pertence a uma Casa.');
    }

    final ids = memberships.map((item) => item.householdId).toList();
    final householdMaps = await _client
        .from('households')
        .select()
        .inFilter('id', ids)
        .isFilter('deleted_at', null)
        .order('name');
    final households = householdMaps
        .map(Household.fromMap)
        .toList(growable: false);
    final preferred = householdId ?? profileMap['default_household_id'] as String?;
    final selected = households.firstWhere(
      (item) => item.id == preferred,
      orElse: () => households.first,
    );

    final results = await Future.wait([
      _client
          .from('household_members')
          .select()
          .eq('household_id', selected.id)
          .isFilter('deleted_at', null)
          .order('joined_at'),
      _client
          .from('accounts')
          .select()
          .eq('household_id', selected.id)
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null)
          .order('sort_order'),
      _client
          .from('categories')
          .select()
          .eq('household_id', selected.id)
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null)
          .order('sort_order'),
      _loadAllTransactions(selected.id),
    ]);

    return FinancaSnapshot(
      profile: Profile.fromMap(profileMap),
      households: households,
      selectedHousehold: selected,
      memberships: (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(HouseholdMember.fromMap)
          .toList(),
      accounts: (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(FinanceAccount.fromMap)
          .toList(),
      categories: (results[2] as List)
          .cast<Map<String, dynamic>>()
          .map(FinanceCategory.fromMap)
          .toList(),
      transactions: (results[3] as List)
          .cast<Map<String, dynamic>>()
          .map(FinanceTransaction.fromMap)
          .toList(),
    );
  }

  Future<List<FinanceTransaction>> listTransactions(
    String householdId, {
    String? memberId,
    String? kind,
    String? search,
  }) async {
    dynamic query = _client
        .from('transactions')
        .select()
        .eq('household_id', householdId)
        .isFilter('deleted_at', null);
    if (memberId != null) query = query.eq('member_id', memberId);
    if (kind != null) query = query.eq('kind', kind);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('description', '%${search.trim()}%');
    }
    final rows = await query.order('occurred_at', ascending: false).limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FinanceTransaction.fromMap)
        .toList();
  }

  Future<String> createTransaction({
    required String householdId,
    required String accountId,
    required String memberId,
    required int amountCents,
    required String kind,
    String? categoryId,
    String? description,
    String? receiptId,
    String visibility = 'household',
  }) async {
    if (amountCents <= 0) throw ArgumentError('O valor deve ser positivo.');
    if (kind != 'expense' && kind != 'income') {
      throw ArgumentError('Tipo de lançamento inválido.');
    }
    final id = _uuidV4();
    try {
      await _client.from('transactions').insert({
        'id': id,
        'household_id': householdId,
        'account_id': accountId,
        'category_id': categoryId,
        'member_id': memberId,
        'created_by': _user.id,
        'kind': kind,
        'amount_cents': amountCents,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'description': _nullIfEmpty(description),
        'receipt_id': receiptId,
        'visibility': visibility,
        'source': receiptId == null ? 'quick_add' : 'ocr',
      });
    } catch (error, stackTrace) {
      if (receiptId != null) {
        await _cleanupReceiptBestEffort(receiptId: receiptId);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return id;
  }

  Future<String> createTransfer({
    required String householdId,
    required String fromAccountId,
    required String toAccountId,
    required String memberId,
    required int amountCents,
    String? description,
  }) async {
    final result = await _client.rpc(
      'create_transfer',
      params: {
        'p_household': householdId,
        'p_from': fromAccountId,
        'p_to': toAccountId,
        'p_amount': amountCents,
        'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
        'p_member': memberId,
        'p_description': _nullIfEmpty(description),
      },
    );
    return result as String;
  }

  Future<FinanceCategory> createCategory({
    required String householdId,
    required String name,
    required String kind,
    String? parentId,
  }) async {
    final map = await _client
        .from('categories')
        .insert({
          'id': _uuidV4(),
          'household_id': householdId,
          'parent_id': parentId,
          'name': name.trim(),
          'kind': kind,
          'icon': 'category',
          'color': '#6F87A6',
        })
        .select()
        .single();
    return FinanceCategory.fromMap(map);
  }

  Future<String> createInvite(
    String householdId, {
    String role = 'adult',
  }) async {
    final value = await _client.rpc(
      'create_invite',
      params: {'p_household': householdId, 'p_role': role, 'p_days': 7},
    );
    return value as String;
  }

  Future<String> redeemInvite(String code) async {
    final value = await _client.rpc(
      'redeem_invite',
      params: {'p_code': code.trim()},
    );
    final householdId = value as String;
    await _client
        .from('profiles')
        .update({'default_household_id': householdId})
        .eq('id', _user.id);
    return householdId;
  }

  Future<void> softDeleteTransaction(String id) async {
    await _client
        .from('transactions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> restoreTransaction(String id) async {
    await _client
        .from('transactions')
        .update({'deleted_at': null})
        .eq('id', id);
  }

  Future<String> duplicateTransaction(FinanceTransaction source) {
    return createTransaction(
      householdId: source.householdId,
      accountId: source.accountId,
      memberId: source.memberId,
      amountCents: source.amountCents,
      kind: source.kind == 'income' ? 'income' : 'expense',
      categoryId: source.categoryId,
      description: source.description,
      visibility: source.visibility,
    );
  }

  Future<ReceiptUpload> uploadReceipt({
    required String householdId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final id = _uuidV4();
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      _ => 'jpg',
    };
    final path = '$householdId/$id.$extension';
    try {
      await _client.storage.from('receipts').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: false),
      );
      await _client.from('receipts').insert({
        'id': id,
        'household_id': householdId,
        'uploaded_by': _user.id,
        'storage_path': path,
        'mime_type': mimeType,
        'byte_size': bytes.length,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
        'ocr_status': 'pending',
      });
    } catch (error, stackTrace) {
      await _cleanupReceiptBestEffort(
        receiptId: id,
        storagePath: path,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    return ReceiptUpload(id: id, path: path);
  }

  Future<void> cleanupReceipt(ReceiptUpload receipt) {
    return _cleanupReceipt(
      receiptId: receipt.id,
      storagePath: receipt.path,
    );
  }

  Future<void> _cleanupReceiptBestEffort({
    required String receiptId,
    String? storagePath,
  }) async {
    try {
      await _cleanupReceipt(
        receiptId: receiptId,
        storagePath: storagePath,
      );
    } catch (_) {
      // Preserve the original operation error when compensation also fails.
    }
  }

  Future<void> _cleanupReceipt({
    required String receiptId,
    String? storagePath,
  }) async {
    var path = storagePath;
    Object? firstError;
    StackTrace? firstStackTrace;

    if (path == null) {
      try {
        final row = await _client
            .from('receipts')
            .select('storage_path')
            .eq('id', receiptId)
            .maybeSingle();
        path = row?['storage_path'] as String?;
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
      }
    }

    try {
      await _client.from('receipts').delete().eq('id', receiptId);
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (path != null) {
      try {
        await _client.storage.from('receipts').remove([path]);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  FinanceCategory? suggestCategory(
    String description,
    List<FinanceCategory> categories,
  ) {
    final text = description.toLowerCase();
    const rules = <String, List<String>>{
      'food.market': ['mercado', 'carrefour', 'atacad', 'supermerc'],
      'food.delivery': ['ifood', 'delivery', 'rappi'],
      'transport.app': ['uber', '99 ', 'taxi'],
      'transport.fuel': ['posto', 'combust', 'gasolina'],
      'health.pharmacy': ['farmácia', 'farmacia', 'drogasil', 'droga raia'],
      'leisure.stream': ['netflix', 'spotify', 'disney', 'prime video'],
      'housing.utils': ['energia', 'luz', 'água', 'agua'],
      'salary.clt': ['salário', 'salario', 'folha'],
    };
    for (final rule in rules.entries) {
      if (rule.value.any(text.contains)) {
        for (final category in categories) {
          if (category.templateKey == rule.key) return category;
        }
      }
    }
    return null;
  }
}

class FinancaSnapshot {
  const FinancaSnapshot({
    required this.profile,
    required this.households,
    required this.selectedHousehold,
    required this.memberships,
    required this.accounts,
    required this.categories,
    required this.transactions,
  });
  final Profile profile;
  final List<Household> households;
  final Household selectedHousehold;
  final List<HouseholdMember> memberships;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
}

class Profile {
  const Profile({required this.id, required this.displayName});
  final String id;
  final String displayName;
  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    displayName: map['display_name'] as String? ?? 'Você',
  );
}

class Household {
  const Household({required this.id, required this.name});
  final String id;
  final String name;
  factory Household.fromMap(Map<String, dynamic> map) =>
      Household(id: map['id'] as String, name: map['name'] as String);
}

class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.displayName,
    required this.role,
    this.userId,
  });
  final String id;
  final String householdId;
  final String? userId;
  final String displayName;
  final String role;
  factory HouseholdMember.fromMap(Map<String, dynamic> map) => HouseholdMember(
    id: map['id'] as String,
    householdId: map['household_id'] as String,
    userId: map['user_id'] as String?,
    displayName: map['display_name'] as String? ?? 'Membro',
    role: map['role'] as String? ?? 'adult',
  );
}

class FinanceAccount {
  const FinanceAccount({required this.id, required this.name});
  final String id;
  final String name;
  factory FinanceAccount.fromMap(Map<String, dynamic> map) =>
      FinanceAccount(id: map['id'] as String, name: map['name'] as String);
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
    this.templateKey,
  });
  final String id;
  final String name;
  final String kind;
  final String? parentId;
  final String? templateKey;
  factory FinanceCategory.fromMap(Map<String, dynamic> map) => FinanceCategory(
    id: map['id'] as String,
    name: map['name'] as String,
    kind: map['kind'] as String,
    parentId: map['parent_id'] as String?,
    templateKey: map['template_key'] as String?,
  );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.householdId,
    required this.accountId,
    required this.memberId,
    required this.kind,
    required this.amountCents,
    required this.occurredAt,
    required this.visibility,
    this.categoryId,
    this.description,
    this.receiptId,
  });
  final String id;
  final String householdId;
  final String accountId;
  final String memberId;
  final String kind;
  final int amountCents;
  final DateTime occurredAt;
  final String visibility;
  final String? categoryId;
  final String? description;
  final String? receiptId;
  int get signedAmountCents =>
      kind == 'expense' || kind == 'transfer_out' ? -amountCents : amountCents;

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) =>
      FinanceTransaction(
        id: map['id'] as String,
        householdId: map['household_id'] as String,
        accountId: map['account_id'] as String,
        memberId: map['member_id'] as String? ?? '',
        categoryId: map['category_id'] as String?,
        kind: map['kind'] as String,
        amountCents: (map['amount_cents'] as num).toInt(),
        occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
        visibility: map['visibility'] as String? ?? 'household',
        description: map['description'] as String?,
        receiptId: map['receipt_id'] as String?,
      );
}

class ReceiptUpload {
  const ReceiptUpload({required this.id, required this.path});
  final String id;
  final String path;
}

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
