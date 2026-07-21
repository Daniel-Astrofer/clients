import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/data/activity_archive_store.dart';
import 'package:kerosene/features/movement/data/activity_cancel.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_filter_engine.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';

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
    test('payment link archive key is namespaced', () {
      expect(paymentLinkArchiveId('abc-123'), 'pl:abc-123');
    });

    test('cancelActivity routes pl_ rows to cancelPaymentRequest', () async {
      final repo = _CancelRoutingRepo();
      final result = await cancelActivity(
        repo,
        _tx(id: 'pl_link-9').copyAsPaymentLink('link-9'),
      );
      expect(repo.cancelledPaymentRequestIds, ['link-9']);
      expect(repo.cancelledTransactionIds, isEmpty);
      expect(result.isCancelled, isTrue);
    });

    test('cancelActivity routes normal rows to cancelTransaction', () async {
      final repo = _CancelRoutingRepo();
      final result = await cancelActivity(
        repo,
        _tx(id: 'tx-uuid', status: TransactionStatus.pending).withCancellable(),
      );
      expect(repo.cancelledTransactionIds, ['tx-uuid']);
      expect(repo.cancelledPaymentRequestIds, isEmpty);
      expect(result.isCancelled, isTrue);
    });
  });
}

extension on Transaction {
  Transaction copyAsPaymentLink(String publicId) {
    return Transaction(
      id: id,
      fromAddress: fromAddress,
      toAddress: toAddress,
      amountSatoshis: amountSatoshis,
      feeSatoshis: feeSatoshis,
      timestamp: timestamp,
      status: status,
      type: type,
      confirmations: confirmations,
      provider: 'PAYMENT_LINK',
      cancellable: true,
      cancelTarget: 'PAYMENT_REQUEST',
      paymentRequestId: publicId,
      paymentRequestPublicId: publicId,
    );
  }

  Transaction withCancellable() {
    return Transaction(
      id: id,
      fromAddress: fromAddress,
      toAddress: toAddress,
      amountSatoshis: amountSatoshis,
      feeSatoshis: feeSatoshis,
      timestamp: timestamp,
      status: status,
      type: type,
      confirmations: confirmations,
      cancellable: true,
      cancelTarget: 'TRANSACTION',
    );
  }
}

class _CancelRoutingRepo implements TransactionRepository {
  final cancelledTransactionIds = <String>[];
  final cancelledPaymentRequestIds = <String>[];

  @override
  Future<Transaction> cancelTransaction(String transactionId) async {
    cancelledTransactionIds.add(transactionId);
    return Transaction(
      id: transactionId,
      fromAddress: 'a',
      toAddress: 'b',
      amountSatoshis: 1,
      feeSatoshis: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      status: TransactionStatus.cancelled,
      type: TransactionType.send,
      confirmations: 0,
    );
  }

  @override
  Future<PaymentLink> cancelPaymentRequest(String requestId) async {
    cancelledPaymentRequestIds.add(requestId);
    return PaymentLink(
      id: requestId,
      userId: 1,
      amountBtc: 0.01,
      description: '',
      depositAddress: '',
      status: 'cancelled',
      paymentRail: 'LIGHTNING',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
