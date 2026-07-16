import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_filter_engine.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';

Transaction _tx({
  required String id,
  required TransactionType type,
  TransactionStatus status = TransactionStatus.confirmed,
  bool isInternal = false,
  bool isLightning = false,
  String? rail,
  String? provider,
  String? walletId,
  int amountSatoshis = 100000,
  int confirmations = 6,
  DateTime? timestamp,
}) {
  return Transaction(
    id: id,
    fromAddress: 'from',
    toAddress: 'to',
    walletId: walletId,
    amountSatoshis: amountSatoshis,
    feeSatoshis: 0,
    serviceFeeSatoshis: 0,
    status: status,
    type: type,
    confirmations: confirmations,
    timestamp: timestamp ?? DateTime.utc(2024, 6, 1),
    isInternal: isInternal,
    isLightning: isLightning,
    rail: rail,
    provider: provider,
  );
}

void main() {
  group('TransactionAxes', () {
    test('classifies internal send as outgoing + internal rail', () {
      final axes = TransactionAxes.classify(
        _tx(
          id: '1',
          type: TransactionType.send,
          isInternal: true,
          rail: 'INTERNAL',
        ),
      );
      expect(axes.direction, TxDirection.outgoing);
      expect(axes.rail, TxRail.internal);
      expect(axes.variant, TxVisualVariant.internalOut);
    });

    test('classifies lightning receive', () {
      final axes = TransactionAxes.classify(
        _tx(
          id: '2',
          type: TransactionType.receive,
          isLightning: true,
          rail: 'LIGHTNING',
        ),
      );
      expect(axes.direction, TxDirection.incoming);
      expect(axes.rail, TxRail.lightning);
      expect(axes.variant, TxVisualVariant.lightningIn);
    });

    test('reconciling lifecycle', () {
      final axes = TransactionAxes.classify(
        _tx(
          id: '3',
          type: TransactionType.send,
          status: TransactionStatus.reconciling,
          isInternal: true,
        ),
      );
      expect(axes.lifecycle, TxLifecycle.reconciling);
      expect(axes.variant, TxVisualVariant.reconciling);
    });
  });

  group('TransactionFilterEngine', () {
    final rows = [
      _tx(id: 'in', type: TransactionType.receive, isInternal: true),
      _tx(id: 'out', type: TransactionType.send, isInternal: true),
      _tx(
        id: 'ln',
        type: TransactionType.receive,
        isLightning: true,
        rail: 'LIGHTNING',
      ),
      _tx(
        id: 'on',
        type: TransactionType.send,
        rail: 'ONCHAIN',
        confirmations: 2,
        status: TransactionStatus.confirming,
      ),
      _tx(
        id: 'pend',
        type: TransactionType.send,
        isInternal: true,
        status: TransactionStatus.pending,
      ),
      _tx(
        id: 'rec',
        type: TransactionType.send,
        isInternal: true,
        status: TransactionStatus.reconciling,
      ),
      _tx(
        id: 'fail',
        type: TransactionType.send,
        status: TransactionStatus.failed,
      ),
      _tx(
        id: 'can',
        type: TransactionType.send,
        status: TransactionStatus.cancelled,
      ),
    ];

    test('incoming only credits', () {
      final r = TransactionFilterEngine.apply(
        source: rows,
        activity: ActivityFilter.incoming,
      );
      expect(r.map((e) => e.id), containsAll(['in', 'ln']));
      expect(r.any((e) => e.id == 'out'), isFalse);
    });

    test('instant is internal only', () {
      final r = TransactionFilterEngine.apply(
        source: rows,
        activity: ActivityFilter.instant,
      );
      expect(r.every((e) => e.id == 'in' || e.id == 'out' || e.id == 'pend' || e.id == 'rec'), isTrue);
      expect(r.any((e) => e.id == 'ln' || e.id == 'on'), isFalse);
    });

    test('lightning isolated', () {
      final r = TransactionFilterEngine.apply(
        source: rows,
        activity: ActivityFilter.lightning,
      );
      expect(r.map((e) => e.id), ['ln']);
    });

    test('in progress includes reconciling', () {
      final r = TransactionFilterEngine.apply(
        source: rows,
        activity: ActivityFilter.inProgress,
      );
      final ids = r.map((e) => e.id).toSet();
      expect(ids.contains('pend'), isTrue);
      expect(ids.contains('rec'), isTrue);
      expect(ids.contains('on'), isTrue); // confirming
      expect(ids.contains('fail'), isFalse);
    });

    test('all excludes cancelled', () {
      final r = TransactionFilterEngine.apply(
        source: rows,
        activity: ActivityFilter.all,
      );
      expect(r.any((e) => e.id == 'can'), isFalse);
    });
  });
}
