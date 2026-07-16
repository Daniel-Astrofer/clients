import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/ledger/domain/balance_display.dart';
import 'package:kerosene/features/ledger/domain/ledger_merge.dart';
import 'package:kerosene/features/ledger/domain/ledger_row.dart';
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

LedgerRow _row({
  required String id,
  required int confs,
  required DateTime updatedAt,
  LedgerStatus status = LedgerStatus.confirming,
  LedgerDirection direction = LedgerDirection.outbound,
  String? blockchainTxid,
  LedgerSource source = LedgerSource.remote,
  int amountSats = 1000,
}) {
  return LedgerRow(
    id: id,
    direction: direction,
    rail: LedgerRail.onchain,
    status: status,
    confirmations: confs,
    amountSats: amountSats,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    blockchainTxid: blockchainTxid,
    source: source,
  );
}

Transaction _tx({
  required String id,
  required int confs,
  required DateTime timestamp,
  TransactionStatus status = TransactionStatus.confirming,
  TransactionType type = TransactionType.send,
  String? blockchainTxid,
  int amount = 1000,
}) {
  return Transaction(
    id: id,
    fromAddress: 'from',
    toAddress: 'to',
    amountSatoshis: amount,
    feeSatoshis: 0,
    status: status,
    type: type,
    confirmations: confs,
    timestamp: timestamp,
    blockchainTxid: blockchainTxid,
    isInternal: false,
    isLightning: false,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 7, 15, 12, 0, 0);
  final t1 = DateTime.utc(2026, 7, 15, 12, 1, 0);
  final t2 = DateTime.utc(2026, 7, 15, 12, 2, 0);

  group('LedgerMerge T1–T8', () {
    test('T1: remote newer with 6 confs beats local 0 confs', () {
      final local = _row(id: 'a', confs: 0, updatedAt: t0);
      final remote = _row(
        id: 'a',
        confs: 6,
        updatedAt: t1,
        status: LedgerStatus.confirmed,
      );
      final m = LedgerMerge.mergeRow(local, remote);
      expect(m.confirmations, 6);
      expect(m.status, LedgerStatus.confirmed);
    });

    test('T2: stale remote with 0 confs does not regress local 6', () {
      final local = _row(
        id: 'a',
        confs: 6,
        updatedAt: t2,
        status: LedgerStatus.confirmed,
      );
      final remote = _row(id: 'a', confs: 0, updatedAt: t1);
      final m = LedgerMerge.mergeRow(local, remote);
      expect(m.confirmations, 6);
      expect(m.status, LedgerStatus.confirmed);
    });

    test('T3: inbound + outbound same chain txid stay two rows', () {
      final out = _row(
        id: 'out-1',
        confs: 0,
        updatedAt: t0,
        direction: LedgerDirection.outbound,
        blockchainTxid: 'deadbeef',
      );
      final inn = _row(
        id: 'in-1',
        confs: 0,
        updatedAt: t0,
        direction: LedgerDirection.inbound,
        blockchainTxid: 'deadbeef',
      );
      final merged = LedgerMerge.mergeLists(
        localRows: const [],
        remoteRows: [out, inn],
      );
      expect(merged, hasLength(2));
      expect(merged.map((r) => r.id).toSet(), {'out-1', 'in-1'});
    });

    test('T4: offline→online unions by id and takes remote confs', () {
      final localOnly = _row(id: 'local-only', confs: 0, updatedAt: t0);
      final localStale = _row(id: 'shared', confs: 0, updatedAt: t0);
      final remoteShared = _row(id: 'shared', confs: 3, updatedAt: t1);
      final remoteNew = _row(id: 'remote-new', confs: 1, updatedAt: t1);

      final merged = LedgerMerge.mergeLists(
        localRows: [localOnly, localStale],
        remoteRows: [remoteShared, remoteNew],
      );
      expect(merged.map((r) => r.id).toSet(), {
        'local-only',
        'shared',
        'remote-new',
      });
      final shared = merged.firstWhere((r) => r.id == 'shared');
      expect(shared.confirmations, 3);
    });

    test('T5: statement 0 confs loses to live API 3 confs same id', () {
      final fromStatement = _row(
        id: 'x',
        confs: 0,
        updatedAt: t1,
        source: LedgerSource.statement,
      );
      final fromApi = _row(id: 'x', confs: 3, updatedAt: t1);
      // Local was statement, remote is API — equal updatedAt → max confs.
      final m = LedgerMerge.mergeRow(fromStatement, fromApi);
      expect(m.confirmations, 3);
    });

    test('T6: equal updatedAt prefers higher confs', () {
      final a = _row(id: 'x', confs: 1, updatedAt: t0);
      final b = _row(id: 'x', confs: 4, updatedAt: t0);
      expect(LedgerMerge.mergeRow(a, b).confirmations, 4);
      expect(LedgerMerge.mergeRow(b, a).confirmations, 4);
    });

    test('T7: filterByWallet keeps only matching wallets', () {
      final a = _row(id: '1', confs: 0, updatedAt: t0).copyWith(
        sourceWalletId: 'wallet-a',
      );
      final b = _row(id: '2', confs: 0, updatedAt: t0).copyWith(
        destinationWalletId: 'wallet-b',
      );
      final c = _row(id: '3', confs: 0, updatedAt: t0).copyWith(
        sourceWalletId: 'wallet-a',
        destinationWalletId: 'wallet-b',
      );
      final filtered = LedgerMerge.filterByWallet([a, b, c], 'wallet-a');
      expect(filtered.map((r) => r.id).toSet(), {'1', '3'});
    });

    test('T8: WATCH_ONLY primary is observed; custodial is available', () {
      expect(
        BalanceDisplayRules.primarySats(
          kind: 'WATCH_ONLY',
          availableSats: 0,
          observedSats: 100,
        ),
        100,
      );
      expect(
        BalanceDisplayRules.primarySats(
          kind: 'CUSTODIAL_ONCHAIN',
          availableSats: 50,
          observedSats: 100,
        ),
        50,
      );
      expect(
        BalanceDisplayRules.showObservedAsSubtitle(
          kind: 'CUSTODIAL_ONCHAIN',
          availableSats: 50,
          observedSats: 100,
        ),
        isTrue,
      );
    });
  });

  group('TransactionLedgerAdapter', () {
    test('mergeTransactionLists preserves two directions for same txid', () {
      final out = _tx(
        id: 'u1',
        confs: 0,
        timestamp: t0,
        type: TransactionType.send,
        blockchainTxid: 'abc',
      );
      final inn = _tx(
        id: 'u2',
        confs: 0,
        timestamp: t0,
        type: TransactionType.receive,
        blockchainTxid: 'abc',
      );
      final merged = TransactionLedgerAdapter.mergeTransactionLists(
        localRows: const [],
        remoteRows: [out, inn],
      );
      expect(merged, hasLength(2));
    });

    test('remote confs update wins over local zero for same id', () {
      final local = _tx(id: 'u1', confs: 0, timestamp: t0);
      final remote = _tx(
        id: 'u1',
        confs: 6,
        timestamp: t1,
        status: TransactionStatus.confirmed,
      );
      final merged = TransactionLedgerAdapter.mergeTransactions(local, remote);
      expect(merged.confirmations, 6);
      expect(merged.status, TransactionStatus.confirmed);
    });
  });
}
