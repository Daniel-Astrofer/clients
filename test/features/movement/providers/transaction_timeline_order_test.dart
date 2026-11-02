import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

void main() {
  group('cold wallet timeline order', () {
    test('sortTransactionsNewestFirst uses createdAt not updatedAt', () {
      final olderReceive = _tx(
        id: 'cold-old',
        timestamp: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 7, 22), // conf bump "today"
        confirmations: 3,
      );
      final todaySend = _tx(
        id: 'today',
        timestamp: DateTime.utc(2026, 7, 21),
        updatedAt: DateTime.utc(2026, 7, 21),
        confirmations: 6,
      );

      final rows = [olderReceive, todaySend];
      sortTransactionsNewestFirst(rows);

      expect(rows.map((t) => t.id).toList(), ['today', 'cold-old']);
    });

    test('upsertFront keeps event time and chronological order on conf bump',
        () {
      final container = ProviderContainer(overrides: [
        sessionStorageScopeProvider.overrideWithValue('user_timeline_fixture'),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(lastTransactionHistoryProvider.notifier);
      notifier.set([
        _tx(
          id: 'today',
          timestamp: DateTime.utc(2026, 7, 21, 18),
          updatedAt: DateTime.utc(2026, 7, 21, 18),
        ),
        _tx(
          id: 'cold-old',
          timestamp: DateTime.utc(2026, 6, 1),
          updatedAt: DateTime.utc(2026, 6, 1),
          confirmations: 1,
          status: TransactionStatus.confirming,
        ),
      ]);

      // Progress / WS conf tick arrives "now" with higher updatedAt.
      notifier.upsertFront(
        _tx(
          id: 'cold-old',
          timestamp: DateTime.utc(2026, 7, 22), // bad optimistic clock
          updatedAt: DateTime.utc(2026, 7, 22),
          confirmations: 2,
          status: TransactionStatus.confirming,
        ),
      );

      final state = container.read(lastTransactionHistoryProvider);
      expect(state.map((t) => t.id).toList(), ['today', 'cold-old']);
      final cold = state.firstWhere((t) => t.id == 'cold-old');
      expect(cold.timestamp, DateTime.utc(2026, 6, 1));
      expect(cold.confirmations, 2);
    });

    test('mergeTransactionHistoryProjection sorts pending by event time', () {
      final remote = [
        _tx(
          id: 'remote-today',
          timestamp: DateTime.utc(2026, 7, 21),
        ),
      ];
      final last = [
        _tx(
          id: 'pending-old',
          timestamp: DateTime.utc(2026, 6, 1),
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
        _tx(
          id: 'pending-newer',
          timestamp: DateTime.utc(2026, 7, 20),
        ),
      ];

      final merged = mergeTransactionHistoryProjection(
        remote: remote,
        last: last,
      );

      expect(
        merged.map((t) => t.id).toList(),
        ['remote-today', 'pending-newer', 'pending-old'],
      );
    });
  });

  test('live confirmation replaces a stale REST row without duplicate entries',
      () {
    final initial = _tx(
        id: 'same',
        timestamp: DateTime.utc(2026, 10, 16),
        status: TransactionStatus.pending);
    final live = _tx(
        id: 'same',
        timestamp: initial.timestamp,
        updatedAt: DateTime.utc(2026, 10, 17),
        confirmations: 3);
    final merged =
        mergeTransactionHistoryProjection(remote: [initial], last: [live]);
    expect(merged, hasLength(1));
    expect(merged.single.status, TransactionStatus.confirmed);
    expect(merged.single.confirmations, 3);
    expect(merged.single.timestamp, initial.timestamp);
  });

  test('newer REST reorg replaces the earlier live confirmation', () {
    final live = _tx(
        id: 'same',
        timestamp: DateTime.utc(2026, 10, 16),
        updatedAt: DateTime.utc(2026, 10, 17),
        confirmations: 3);
    final reorg = _tx(
        id: 'same',
        timestamp: live.timestamp,
        updatedAt: DateTime.utc(2026, 10, 18),
        confirmations: 0,
        status: TransactionStatus.confirming);
    final merged =
        mergeTransactionHistoryProjection(remote: [reorg], last: [live]);
    expect(merged.single.status, TransactionStatus.confirming);
    expect(merged.single.confirmations, 0);
  });
}

Transaction _tx({
  required String id,
  required DateTime timestamp,
  DateTime? updatedAt,
  int confirmations = 0,
  TransactionStatus status = TransactionStatus.confirmed,
  TransactionType type = TransactionType.receive,
}) {
  return Transaction(
    id: id,
    fromAddress: '',
    toAddress: '',
    amountSatoshis: 1000,
    feeSatoshis: 0,
    status: status,
    type: type,
    confirmations: confirmations,
    timestamp: timestamp,
    updatedAt: updatedAt ?? timestamp,
    isInternal: false,
    isLightning: false,
    rail: 'ONCHAIN',
    provider: 'COLD_OBSERVER',
  );
}
