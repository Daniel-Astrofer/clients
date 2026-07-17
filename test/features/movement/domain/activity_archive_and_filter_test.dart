import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_filter_engine.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';

Transaction _tx({
  required String id,
  TransactionStatus status = TransactionStatus.confirmed,
  String? failureCode,
  TransactionType type = TransactionType.receive,
}) {
  return Transaction(
    id: id,
    fromAddress: 'a',
    toAddress: 'b',
    amountSatoshis: 1000,
    feeSatoshis: 0,
    timestamp: DateTime.utc(2026, 1, 1),
    status: status,
    type: type,
    confirmations: status == TransactionStatus.confirmed ? 6 : 0,
    failureCode: failureCode,
  );
}

void main() {
  group('USER_CANCELLED display', () {
    test('maps failed+USER_CANCELLED to cancelled displayStatus', () {
      final tx = _tx(
        id: '1',
        status: TransactionStatus.failed,
        failureCode: 'USER_CANCELLED',
      );
      expect(tx.displayStatus, TransactionStatus.cancelled);
      expect(tx.isCancelled, isTrue);
      expect(tx.isArchiveEligible, isTrue);
    });
  });

  group('archive filter', () {
    test('all includes non-archived cancelled', () {
      final cancelled = _tx(id: 'c1', status: TransactionStatus.cancelled);
      final ok = TransactionFilterEngine.matchesActivity(
        cancelled,
        ActivityFilter.all,
        archivedIds: {},
      );
      expect(ok, isTrue);
    });

    test('all excludes archived', () {
      final cancelled = _tx(id: 'c1', status: TransactionStatus.cancelled);
      final ok = TransactionFilterEngine.matchesActivity(
        cancelled,
        ActivityFilter.all,
        archivedIds: {'c1'},
      );
      expect(ok, isFalse);
    });

    test('archived filter only archived ids', () {
      final cancelled = _tx(id: 'c1', status: TransactionStatus.cancelled);
      expect(
        TransactionFilterEngine.matchesActivity(
          cancelled,
          ActivityFilter.archived,
          archivedIds: {'c1'},
        ),
        isTrue,
      );
      expect(
        TransactionFilterEngine.matchesActivity(
          cancelled,
          ActivityFilter.archived,
          archivedIds: {},
        ),
        isFalse,
      );
    });

    test('cancelled filter excludes archived', () {
      final cancelled = _tx(id: 'c1', status: TransactionStatus.cancelled);
      expect(
        TransactionFilterEngine.matchesActivity(
          cancelled,
          ActivityFilter.cancelled,
          archivedIds: {},
        ),
        isTrue,
      );
      expect(
        TransactionFilterEngine.matchesActivity(
          cancelled,
          ActivityFilter.cancelled,
          archivedIds: {'c1'},
        ),
        isFalse,
      );
    });

    test('taxonomy lifecycle for user cancel', () {
      final tx = _tx(
        id: '1',
        status: TransactionStatus.failed,
        failureCode: 'USER_CANCELLED',
      );
      final axes = TransactionAxes.classify(tx);
      expect(axes.lifecycle, TxLifecycle.cancelled);
    });
  });
}
