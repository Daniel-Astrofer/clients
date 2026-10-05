import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/app/security/local_transaction_sqlite.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/core/telemetry/ledger_telemetry.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart'
    show Transaction;

/// Encrypted / integrity-sealed, session-scoped local ledger of transactions.
///
/// **Storage layers**
/// - **SQLite** (mobile/desktop): row projection, up to [maxEntries]
/// - **Secure storage**: HMAC key + integrity seal (fingerprint MAC)
/// - **Legacy**: full JSON blob with MAC (v2) still loadable and migrated
///
/// **Logout policy:** logout never wipes this projection.
/// Call [clear] only on explicit user wipe.
class LocalTransactionHistoryStore {
  LocalTransactionHistoryStore(SecureStorageService secureStorage)
      : _secureStorage = _SecureStorageKvAdapter(secureStorage),
        _useSqlite = true;

  /// Test / alternative backends (JSON+HMAC only; no SQLite).
  LocalTransactionHistoryStore.withKv(this._secureStorage) : _useSqlite = false;

  final LocalHistoryKvStore _secureStorage;
  final bool _useSqlite;

  static const int maxEntries = LocalTransactionSqlite.maxEntries;
  static const int _blobVersion = 2;
  static const int _sealVersion = 3;

  String get _keyPrefix => '${keroseneSecurePrefix()}tx_history_v1';
  String get _macKeyPrefix => '${keroseneSecurePrefix()}tx_history_mac_v1';
  String get _sealPrefix => '${keroseneSecurePrefix()}tx_history_seal_v3';

  String _storageKey(String sessionScope) =>
      '$_keyPrefix:${sessionScope.trim()}';

  String _macKeyStorage(String sessionScope) =>
      '$_macKeyPrefix:${sessionScope.trim()}';

  String _sealKey(String sessionScope) => '$_sealPrefix:${sessionScope.trim()}';

  Future<List<int>> _macKeyBytes(String sessionScope) async {
    final keyName = _macKeyStorage(sessionScope);
    final existing = await _secureStorage.read(key: keyName);
    if (existing != null && existing.length >= 32) {
      return utf8.encode(existing);
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final digest = base64UrlEncode(bytes);
    await _secureStorage.write(key: keyName, value: digest);
    return utf8.encode(digest);
  }

  String _hmacHex(List<int> key, String payload) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Compact integrity fingerprint (no full JSON in secure storage).
  String fingerprint(List<Transaction> txs) {
    final parts = txs.map((t) {
      return [
        t.id,
        t.confirmations,
        t.amountSatoshis,
        t.effectiveUpdatedAt.toUtc().millisecondsSinceEpoch,
      ].join('|');
    });
    return parts.join(';');
  }

  Future<void> _writeSeal(String scope, List<Transaction> txs) async {
    final key = await _macKeyBytes(scope);
    final fp = fingerprint(txs);
    final mac = _hmacHex(key, fp);
    await _secureStorage.write(
      key: _sealKey(scope),
      value: jsonEncode({'v': _sealVersion, 'mac': mac, 'n': txs.length}),
    );
  }

  Future<bool> _verifySeal(String scope, List<Transaction> txs) async {
    final raw = await _secureStorage.read(key: _sealKey(scope));
    if (raw == null || raw.isEmpty) {
      // No seal yet (migration) — accept once.
      return true;
    }
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return false;
      final mac = map['mac']?.toString() ?? '';
      final key = await _macKeyBytes(scope);
      final expected = _hmacHex(key, fingerprint(txs));
      if (mac != expected) {
        // ignore: unawaited_futures
        LedgerTelemetry.recordMacDiscarded();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Transaction>> load(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return const [];

    // Prefer SQLite projection when available.
    if (_useSqlite && !kIsWeb) {
      final sqlRows = await LocalTransactionSqlite.load(scope);
      if (sqlRows != null && sqlRows.isNotEmpty) {
        final sealRaw = await _secureStorage.read(key: _sealKey(scope));
        if (sealRaw == null || sealRaw.isEmpty) {
          // First load after SQLite migration without seal — write seal now.
          await _writeSeal(scope, sqlRows);
          return sqlRows;
        }
        if (await _verifySeal(scope, sqlRows)) {
          return sqlRows;
        }
        // Tamper — wipe projection.
        await LocalTransactionSqlite.clear(scope);
        await _secureStorage.delete(key: _sealKey(scope));
        return const [];
      }
    }

    // Legacy secure-storage blob (v1 plain / v2 HMAC JSON list).
    try {
      final raw = await _secureStorage.read(key: _storageKey(scope));
      if (raw == null || raw.trim().isEmpty) return const [];

      final listJson = await _unwrapPayload(scope, raw);
      if (listJson == null) return const [];

      final decoded = jsonDecode(listJson);
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

      // Migrate to SQLite + seal when possible.
      if (items.isNotEmpty && _useSqlite && !kIsWeb) {
        final migrated = await LocalTransactionSqlite.save(scope, items);
        if (migrated) {
          await _writeSeal(scope, items);
          // Drop bulky legacy blob only after successful migration.
          await _secureStorage.delete(key: _storageKey(scope));
        }
      }
      return items;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionHistoryStore.load failed: $e');
      }
      return const [];
    }
  }

  /// Returns JSON list string or null if blob invalid / tampered.
  Future<String?> _unwrapPayload(String scope, String raw) async {
    final trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      return trimmed;
    }
    try {
      final map = jsonDecode(trimmed);
      if (map is! Map) return null;
      final payload = map['payload']?.toString();
      final mac = map['mac']?.toString();
      if (payload == null || mac == null || payload.isEmpty || mac.isEmpty) {
        return null;
      }
      final key = await _macKeyBytes(scope);
      final expected = _hmacHex(key, payload);
      if (expected != mac) {
        if (kDebugMode) {
          debugPrint(
            'LocalTransactionHistoryStore: MAC mismatch — discarding blob',
          );
        }
        // ignore: unawaited_futures
        LedgerTelemetry.recordMacDiscarded();
        await _secureStorage.delete(key: _storageKey(scope));
        return null;
      }
      return payload;
    } catch (_) {
      return null;
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

    // Primary: SQLite rows + compact integrity seal.
    if (_useSqlite && !kIsWeb) {
      final ok = await LocalTransactionSqlite.save(scope, capped);
      if (ok) {
        await _writeSeal(scope, capped);
        // Remove legacy full blob if present.
        await _secureStorage.delete(key: _storageKey(scope));
        return;
      }
    }

    // Fallback: HMAC blob in secure storage (web / sqlite failure).
    final payload = jsonEncode(capped.map((t) => t.toJson()).toList());
    final key = await _macKeyBytes(scope);
    final mac = _hmacHex(key, payload);
    final blob = jsonEncode({
      'v': _blobVersion,
      'mac': mac,
      'payload': payload,
    });
    await _secureStorage.write(key: _storageKey(scope), value: blob);
    await _writeSeal(scope, capped);
  }

  Future<List<Transaction>> mergeAndPersist({
    required String sessionScope,
    required List<Transaction> incoming,
  }) async {
    final existing = await load(sessionScope);
    final merged = TransactionLedgerAdapter.mergeTransactionLists(
      localRows: existing,
      remoteRows: incoming,
      maxEntries: maxEntries,
    );
    await save(sessionScope, merged);
    return merged;
  }

  /// Destructive. Do **not** call from logout — only from explicit data wipe.
  Future<void> clear(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return;
    await _secureStorage.delete(key: _storageKey(scope));
    await _secureStorage.delete(key: _macKeyStorage(scope));
    await _secureStorage.delete(key: _sealKey(scope));
    if (_useSqlite && !kIsWeb) {
      await LocalTransactionSqlite.clear(scope);
    }
  }
}

/// Minimal KV used by the store (real = [SecureStorageService], tests = memory).
abstract class LocalHistoryKvStore {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class _SecureStorageKvAdapter implements LocalHistoryKvStore {
  _SecureStorageKvAdapter(this._inner);
  final SecureStorageService _inner;

  @override
  Future<void> write({required String key, required String value}) =>
      _inner.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _inner.read(key: key);

  @override
  Future<void> delete({required String key}) => _inner.delete(key: key);
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
