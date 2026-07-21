import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';

void main() {
  group('transactionsForAccount', () {
    test('matches KFE wallet UUID on source/destination fields', () {
      const walletId = '61a8bb23-e18e-4f32-8414-9844e7300c14';
      final account = BitcoinAccount(
        id: walletId,
        type: 'WATCH_ONLY_COLD_WALLET',
        custody: 'WATCH_ONLY',
        status: 'ACTIVE',
        label: 'Cold',
        riskTier: 'BRONZE',
        balanceAvailableSats: 0,
        balancePendingSats: 0,
        balanceLockedSats: 0,
        balanceAutoHoldSats: 0,
        observedBalanceSats: 1000,
        coldWalletId: walletId,
      );
      final tx = Transaction(
        id: 'tx-1',
        fromAddress: 'placeholder',
        toAddress: 'placeholder',
        sourceWalletId: walletId,
        amountSatoshis: 1000,
        feeSatoshis: 0,
        status: TransactionStatus.confirmed,
        type: TransactionType.withdrawal,
        confirmations: 3,
        timestamp: DateTime(2026, 7, 1),
        description: 'Envio carteira fria',
      );

      final rows = transactionsForAccount(
        account: account,
        transactions: [tx],
        requests: const [],
      );

      expect(rows, hasLength(1));
      expect(rows.first.id, 'tx-1');
    });
  });

  group('mergeColdPsbtBroadcastsIntoHistory', () {
    test('synthesizes broadcast workflows missing from history', () {
      final workflows = [
        PsbtWorkflowView(
          id: 'wf-1',
          coldWalletId: 'cold-1',
          unsignedPsbt: 'cHNidP',
          status: 'BROADCAST',
          destinationAddress: 'tb1qdest',
          amountSats: 5000,
          estimatedFeeSats: 200,
          broadcastTxid: 'aabbcc',
          expiresAt: '',
          createdAt: '2026-07-01T12:00:00Z',
        ),
      ];

      final merged = mergeColdPsbtBroadcastsIntoHistory(
        transactions: const [],
        workflows: workflows,
        coldWalletId: 'cold-1',
      );

      expect(merged, hasLength(1));
      expect(merged.first.blockchainTxid, 'aabbcc');
      expect(merged.first.description, 'Envio carteira fria');
      expect(merged.first.sourceWalletId, 'cold-1');
    });

    test('skips workflows already present by txid', () {
      final existing = Transaction(
        id: 'kfe-1',
        fromAddress: 'cold-1',
        toAddress: 'tb1qdest',
        amountSatoshis: 5000,
        feeSatoshis: 200,
        status: TransactionStatus.confirming,
        type: TransactionType.withdrawal,
        confirmations: 1,
        timestamp: DateTime(2026, 7, 1),
        blockchainTxid: 'aabbcc',
      );
      final workflows = [
        PsbtWorkflowView(
          id: 'wf-1',
          coldWalletId: 'cold-1',
          unsignedPsbt: 'cHNidP',
          status: 'BROADCAST',
          destinationAddress: 'tb1qdest',
          amountSats: 5000,
          estimatedFeeSats: 200,
          broadcastTxid: 'aabbcc',
          expiresAt: '',
          createdAt: '2026-07-01T12:00:00Z',
        ),
      ];

      final merged = mergeColdPsbtBroadcastsIntoHistory(
        transactions: [existing],
        workflows: workflows,
        coldWalletId: 'cold-1',
      );

      expect(merged, hasLength(1));
      expect(merged.first.id, 'kfe-1');
    });
  });
}
