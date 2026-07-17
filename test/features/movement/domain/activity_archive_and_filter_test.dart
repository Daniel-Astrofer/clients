import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
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

  group('payment link cancel + archive keys', () {
    test('open quote maps to cancellable history row', () {
      final link = PaymentLink(
        id: 'abc-123',
        userId: 1,
        amountBtc: 0.01,
        description: 'Test',
        depositAddress: 'tb1qtest',
        status: 'pending',
        paymentRail: 'LIGHTNING',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final tx = link.toTransaction();
      expect(tx.id, 'pl_abc-123');
      expect(tx.cancellable, isTrue);
      expect(tx.cancelTarget, 'PAYMENT_REQUEST');
      expect(tx.paymentRequestPublicId, 'abc-123');
      expect(paymentLinkArchiveId(link.id), 'pl:abc-123');
    });

    test('cancelled quote is not cancellable and is archive-eligible', () {
      final link = PaymentLink(
        id: 'xyz',
        userId: 1,
        amountBtc: 0.02,
        description: '',
        depositAddress: '',
        status: 'cancelled',
        paymentRail: 'ONCHAIN',
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final tx = link.toTransaction();
      expect(tx.cancellable, isFalse);
      expect(tx.isCancelled, isTrue);
      expect(tx.isArchiveEligible, isTrue);
    });
  });
}
