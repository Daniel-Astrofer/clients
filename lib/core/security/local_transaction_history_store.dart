import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

/// Encrypted, session-scoped local ledger of transactions.
///
/// Backend only retains a short statement window (~24h). The app must keep a
/// durable on-device history so the extrato survives after the server prunes.
///
/// Storage is [SecureStorageService] (Keychain / EncryptedSharedPreferences).
class LocalTransactionHistoryStore {
  LocalTransactionHistoryStore(this._secureStorage);

  final SecureStorageService _secureStorage;

  static const int maxEntries = 500;
  static const String _keyPrefix = 'tx_history_v1';

  String _storageKey(String sessionScope) =>
      '$_keyPrefix:${sessionScope.trim()}';

  Future<List<Transaction>> load(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return const [];
    try {
      final raw = await _secureStorage.read(key: _storageKey(scope));
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <Transaction>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          items.add(
            Transaction.fromJson(Map<String, dynamic>.from(entry)),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('LocalTransactionHistoryStore: skip corrupt entry: $e');
          }
        }
      }
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionHistoryStore.load failed: $e');
      }
      return const [];
    }
  }

  Future<void> save(String sessionScope, List<Transaction> transactions) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return;
    final capped = List<Transaction>.from(transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (capped.length > maxEntries) {
      capped.removeRange(maxEntries, capped.length);
    }
    final payload = jsonEncode(capped.map((t) => t.toJson()).toList());
    await _secureStorage.write(key: _storageKey(scope), value: payload);
  }

  /// Upsert remote/local rows, prefer richer entries (same rules as online merge).
  Future<List<Transaction>> mergeAndPersist({
    required String sessionScope,
    required List<Transaction> incoming,
  }) async {
    final existing = await load(sessionScope);
    final merged = <String, Transaction>{};

    void upsert(Transaction tx) {
      final key = _historyKey(tx);
      final current = merged[key];
      if (current == null || _prefer(tx, current)) {
        merged[key] = tx;
      }
    }

    for (final tx in existing) {
      upsert(tx);
    }
    for (final tx in incoming) {
      upsert(tx);
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await save(sessionScope, list);
    return list;
  }

  Future<void> clear(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return;
    await _secureStorage.delete(key: _storageKey(scope));
  }

  static String _historyKey(Transaction transaction) {
    final blockchainTxid = transaction.blockchainTxid?.trim() ?? '';
    if (blockchainTxid.isNotEmpty) {
      return 'blockchain:$blockchainTxid';
    }
    final paymentHash = transaction.paymentHash?.trim() ?? '';
    if (paymentHash.isNotEmpty) {
      return 'paymentHash:$paymentHash';
    }
    return 'transaction:${transaction.id.trim()}';
  }

  static bool _prefer(Transaction candidate, Transaction current) {
    final cScore = _score(candidate);
    final curScore = _score(current);
    if (cScore != curScore) return cScore > curScore;
    return candidate.timestamp.isAfter(current.timestamp);
  }

  static int _score(Transaction t) {
    var s = 0;
    if ((t.blockchainTxid ?? '').isNotEmpty) s += 6;
    if ((t.paymentHash ?? '').isNotEmpty) s += 5;
    if ((t.invoiceId ?? '').isNotEmpty) s += 4;
    if (t.confirmations > 0) s += 2;
    if (t.feeSatoshis > 0) s += 1;
    return s;
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localTransactionHistoryStoreProvider =
    Provider<LocalTransactionHistoryStore>((ref) {
  return LocalTransactionHistoryStore(ref.watch(secureStorageServiceProvider));
});

/// Reactive snapshot of the secure on-device ledger for the active session.
final localTransactionHistoryProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final scope = ref.watch(sessionStorageScopeProvider);
  if (scope == null || scope.trim().isEmpty) {
    return const <Transaction>[];
  }
  final store = ref.watch(localTransactionHistoryStoreProvider);
  return store.load(scope);
});
