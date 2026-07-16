import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/statement_insights_provider.dart';

void main() {
  test('merge by id keeps inbound and outbound with same chain txid as two rows',
      () {
    final local = [
      _tx(
        id: 'uuid-out',
        blockchainTxid: 'abc123',
        amountSatoshis: 1000,
        type: TransactionType.withdrawal,
      ),
    ];
    final remote = [
      _tx(
        id: 'uuid-in',
        blockchainTxid: 'abc123',
        amountSatoshis: 1000,
        type: TransactionType.deposit,
      ),
    ];

    final merged = mergeInsightTransactions(remote: remote, local: local);
    expect(merged, hasLength(2));
    expect(merged.map((t) => t.id).toSet(), {'uuid-out', 'uuid-in'});
  });

  test('merge same id upgrades confs from remote', () {
    final local = [
      _tx(
        id: 'same',
        amountSatoshis: 1000,
        confirmations: 0,
        status: TransactionStatus.confirming,
      ),
    ];
    final remote = [
      _tx(
        id: 'same',
        amountSatoshis: 1000,
        confirmations: 6,
        feeSatoshis: 50,
        status: TransactionStatus.confirmed,
      ),
    ];

    final merged = mergeInsightTransactions(remote: remote, local: local);
    expect(merged, hasLength(1));
    expect(merged.single.confirmations, 6);
    expect(merged.single.feeSatoshis, 50);
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

  test('dedupe drops pl_ when KFE row has same blockchain txid', () {
    final rows = [
      _tx(
        id: 'kfe-uuid',
        blockchainTxid: 'deadbeef',
        amountSatoshis: 5000,
        type: TransactionType.deposit,
        provider: 'PAYMENT_LINK',
      ),
      _tx(
        id: 'pl_link1',
        blockchainTxid: 'deadbeef',
        amountSatoshis: 5000,
        type: TransactionType.receive,
        provider: 'PAYMENT_LINK',
      ),
    ];
    final deduped = TransactionLedgerAdapter.dedupePaymentLinkOverlays(rows);
    expect(deduped.map((t) => t.id).toList(), ['kfe-uuid']);
  });
}

Transaction _tx({
  required String id,
  String? blockchainTxid,
  String? walletId,
  String? provider,
  required int amountSatoshis,
  int feeSatoshis = 0,
  int serviceFeeSatoshis = 0,
  int confirmations = 1,
  TransactionStatus status = TransactionStatus.confirmed,
  TransactionType type = TransactionType.send,
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
    status: status,
    type: type,
    confirmations: confirmations,
    timestamp: timestamp ?? DateTime(2026, 6, 1),
    blockchainTxid: blockchainTxid,
    provider: provider,
  );
}
