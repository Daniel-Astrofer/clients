import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

Transaction _operation({required int debit, required DateTime updatedAt}) =>
    Transaction(
      id: 'operation',
      fromAddress: 'source',
      toAddress: 'destination',
      amountSatoshis: 100000,
      feeSatoshis: 1000,
      serviceFeeSatoshis: 300,
      totalDebitedSatoshis: debit,
      status: TransactionStatus.pending,
      type: TransactionType.withdrawal,
      confirmations: 0,
      timestamp: DateTime.utc(2026, 10, 15),
      updatedAt: updatedAt,
      rail: 'ONCHAIN',
      provider: 'BITCOIN_CORE',
      cancellable: true,
      cancelTarget: 'PAYMENT_REQUEST',
      paymentRequestId: 'request-private',
      paymentRequestPublicId: 'request-public',
      paymentRequestStatus: 'PENDING',
      hasNetworkFee: true,
    );

void main() {
  test('ledger hydration retains the complete recorded operation', () {
    final operation =
        _operation(debit: 100000, updatedAt: DateTime.utc(2026, 10, 17));
    final merged = TransactionLedgerAdapter.mergeTransactionLists(
        localRows: [], remoteRows: [operation]);
    expect(merged.single.toJson(), operation.toJson());
    expect(merged.single.signedDisplaySatoshis, 100000);
  });

  for (final newestIsRemote in [false, true]) {
    test('the newest recorded debit wins with remote newer=$newestIsRemote',
        () {
      final old =
          _operation(debit: 100000, updatedAt: DateTime.utc(2026, 10, 16));
      final current =
          _operation(debit: 102000, updatedAt: DateTime.utc(2026, 10, 17));
      final merged = TransactionLedgerAdapter.mergeTransactions(
          newestIsRemote ? old : current, newestIsRemote ? current : old);
      expect(merged.totalDebitedSatoshis, 102000);
      expect(merged.signedDisplaySatoshis, 102000);
      expect(merged.paymentRequestId, 'request-private');
      expect(merged.paymentRequestPublicId, 'request-public');
      expect(merged.paymentRequestStatus, 'PENDING');
    });
  }
}
