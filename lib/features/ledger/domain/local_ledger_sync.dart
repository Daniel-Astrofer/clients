import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';

import 'transaction_ledger_adapter.dart';

/// Coordinates local projection + remote batch apply (design LocalLedgerSync).
///
/// UI should call [hydrateAndMerge] after every successful history pull.
class LocalLedgerSync {
  LocalLedgerSync(this._store);

  final LocalTransactionHistoryStore _store;

  static const int maxEntries = LocalTransactionHistoryStore.maxEntries;

  /// Load durable local rows, merge with [remote], persist, return projection.
  Future<List<Transaction>> hydrateAndMerge({
    required String sessionScope,
    required List<Transaction> remote,
  }) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return List<Transaction>.from(remote);

    final local = await _store.load(scope);
    final merged = TransactionLedgerAdapter.mergeTransactionLists(
      localRows: local,
      remoteRows: remote,
      maxEntries: maxEntries,
    );
    await _store.save(scope, merged);
    return merged;
  }

  /// Offline: serve durable projection only.
  Future<List<Transaction>> loadLocal(String sessionScope) {
    return _store.load(sessionScope);
  }

  Future<void> clear(String sessionScope) => _store.clear(sessionScope);
}
