import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/statement_insights_provider.dart';

void main() {
  test('merge prefers richer remote details for same chain id', () {
    final local = [
      _tx(
        id: 'local-1',
        blockchainTxid: 'abc123',
        amountSatoshis: 1000,
        feeSatoshis: 0,
      ),
    ];
    final remote = [
      _tx(
        id: 'remote-1',
        blockchainTxid: 'abc123',
        amountSatoshis: 1000,
        feeSatoshis: 50,
        serviceFeeSatoshis: 10,
        walletId: 'wallet-a',
      ),
    ];

    final merged = mergeInsightTransactions(remote: remote, local: local);
    expect(merged, hasLength(1));
    expect(merged.single.id, 'remote-1');
    expect(merged.single.feeSatoshis, 50);
    expect(merged.single.serviceFeeSatoshis, 10);
  });

  test('merge keeps distinct transactions and sorts newest first', () {
    final local = [
      _tx(
        id: 'older',
        amountSatoshis: 1,
        timestamp: DateTime(2026, 1, 1),
      ),
    ];
    final remote = [
      _tx(
        id: 'newer',
        amountSatoshis: 2,
        timestamp: DateTime(2026, 6, 1),
      ),
    ];

    final merged = mergeInsightTransactions(remote: remote, local: local);
    expect(merged.map((tx) => tx.id).toList(), ['newer', 'older']);
  });
}

Transaction _tx({
  required String id,
  String? blockchainTxid,
  String? walletId,
  required int amountSatoshis,
  int feeSatoshis = 0,
  int serviceFeeSatoshis = 0,
  DateTime? timestamp,
}) {
  return Transaction(
    id: id,
    fromAddress: 'a',
    toAddress: 'b',
    walletId: walletId,
    amountSatoshis: amountSatoshis,
    feeSatoshis: feeSatoshis,
    serviceFeeSatoshis: serviceFeeSatoshis,
    status: TransactionStatus.confirmed,
    type: TransactionType.send,
    confirmations: 1,
    timestamp: timestamp ?? DateTime(2026, 6, 1),
    blockchainTxid: blockchainTxid,
  );
}
