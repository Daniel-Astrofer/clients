import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/statement_report.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/services/statement_report_calculator.dart';

void main() {
  final now = DateTime(2026, 6, 30, 12);

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('counts external deposit as incoming movement', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'deposit-1',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 100000,
          type: TransactionType.deposit,
          timestamp: DateTime(2026, 6, 10),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.incomingSats, 100000);
    expect(report.outgoingSats, 0);
    expect(report.feeSats, 0);
    expect(report.netSats, 100000);
    expect(_bucketValue(report, 'jun.', 'wallet-global'), 100000);
  });

  test('counts withdrawal amount and keeps fee separated', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'withdrawal-1',
          walletId: 'wallet-global',
          sourceWalletId: 'wallet-global',
          amountSatoshis: 50000,
          feeSatoshis: 1000,
          type: TransactionType.withdrawal,
          timestamp: DateTime(2026, 6, 11),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.incomingSats, 0);
    expect(report.outgoingSats, 50000);
    expect(report.feeSats, 1000);
    expect(report.netSats, -51000);
    expect(_bucketValue(report, 'jun.', 'wallet-global'), 51000);
  });

  test('separates network fee and service fee and exposes net', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'send-1',
          walletId: 'wallet-global',
          sourceWalletId: 'wallet-global',
          amountSatoshis: 20000,
          feeSatoshis: 300,
          serviceFeeSatoshis: 150,
          type: TransactionType.send,
          timestamp: DateTime(2026, 6, 12),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.outgoingSats, 20000);
    expect(report.feeSats, 300);
    expect(report.serviceFeeSats, 150);
    expect(report.totalFeesSats, 450);
    expect(report.netSats, -20450);
    expect(_bucketValue(report, 'jun.', 'wallet-global'), 20450);
  });

  test('keeps internal transfer out of global external totals', () {
    final report = StatementReportCalculator.calculate(
      wallets: [
        _wallet(id: 'wallet-a', name: 'Carteira A'),
        _wallet(id: 'wallet-b', name: 'Carteira B'),
      ],
      transactions: [
        _transaction(
          id: 'internal-1',
          walletId: 'wallet-a',
          sourceWalletId: 'wallet-a',
          destinationWalletId: 'wallet-b',
          amountSatoshis: 20000,
          feeSatoshis: 200,
          type: TransactionType.send,
          timestamp: DateTime(2026, 6, 12),
          isInternal: true,
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.incomingSats, 0);
    expect(report.outgoingSats, 0);
    expect(report.internalTransferSats, 20000);
    expect(report.feeSats, 200);
    expect(_bucketValue(report, 'jun.', 'wallet-a'), 20200);
    expect(_bucketValue(report, 'jun.', 'wallet-b'), 20000);
  });

  test('ignores failed transactions', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'failed-1',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 90000,
          type: TransactionType.deposit,
          status: TransactionStatus.failed,
          timestamp: DateTime(2026, 6, 14),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.incomingSats, 0);
    expect(report.outgoingSats, 0);
    expect(_bucketValue(report, 'jun.', 'wallet-global'), 0);
  });

  test('marks report partial when the recent history page is full', () {
    final transactions = List.generate(
      StatementReportCalculator.partialHistoryThreshold,
      (index) => _transaction(
        id: 'tx-$index',
        walletId: 'wallet-global',
        destinationWalletId: 'wallet-global',
        amountSatoshis: 1000,
        type: TransactionType.deposit,
        timestamp: DateTime(2026, 6, 1 + (index % 20)),
      ),
    );

    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: transactions,
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.isPartial, isTrue);
  });

  test('marks report partial when oldest loaded tx is after period start', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'recent-only',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 5000,
          type: TransactionType.deposit,
          timestamp: DateTime(2026, 6, 20),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    // Monthly window starts months earlier than the single loaded tx.
    expect(report.isPartial, isTrue);
    expect(report.periodStart.isBefore(DateTime(2026, 6, 20)), isTrue);
  });

  test('keeps distribution ordered by real balance without inflating zeroes',
      () {
    final report = StatementReportCalculator.calculate(
      wallets: [
        _wallet(id: 'wallet-empty', name: 'Carteira vazia', balance: 0),
        _wallet(id: 'wallet-main', name: 'Carteira principal', balance: 0.02),
        _wallet(id: 'wallet-savings', name: 'Reserva', balance: 0.01),
      ],
      transactions: const [],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(
      report.distribution.map((segment) => segment.label),
      ['Carteira principal', 'Reserva', 'Carteira vazia'],
    );
    expect(report.distribution.first.percent, closeTo(66.666, 0.01));
    expect(report.distribution.last.percent, 0);
    expect(report.distribution.last.visualSats, 0);
    expect(report.dominantWalletName, 'Carteira principal');
  });

  test('exposes audit counts for the report data basis', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-global', name: 'Carteira Global')],
      transactions: [
        _transaction(
          id: 'included',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 1000,
          type: TransactionType.deposit,
          timestamp: DateTime(2026, 6, 4),
        ),
        _transaction(
          id: 'failed',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 2000,
          type: TransactionType.deposit,
          status: TransactionStatus.failed,
          timestamp: DateTime(2026, 6, 5),
        ),
        _transaction(
          id: 'outside-range',
          walletId: 'wallet-global',
          destinationWalletId: 'wallet-global',
          amountSatoshis: 3000,
          type: TransactionType.deposit,
          timestamp: DateTime(2025, 12, 31),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.walletCount, 1);
    expect(report.loadedTransactionCount, 3);
    expect(report.includedTransactionCount, 1);
    expect(report.ignoredFailedTransactionCount, 1);
    expect(report.ignoredOutOfPeriodTransactionCount, 1);
    expect(report.unclassifiedTransactionCount, 0);
  });

  test('prefers BitcoinAccount labels and match keys over legacy wallets', () {
    final report = StatementReportCalculator.calculate(
      accounts: [
        const BitcoinAccount(
          id: 'acct-cold',
          type: 'WATCH_ONLY_COLD_WALLET',
          custody: 'WATCH_ONLY',
          status: 'ACTIVE',
          label: 'Cofre frio',
          riskTier: 'GOLD',
          coldWalletId: 'cold-1',
          observedBalanceSats: 250000,
        ),
        const BitcoinAccount(
          id: 'acct-global',
          type: 'INTERNAL_CARD',
          custody: 'KEROSENE_CUSTODIAL',
          status: 'ACTIVE',
          label: 'Carteira Global',
          riskTier: 'BRONZE',
          balanceAvailableSats: 100000,
        ),
      ],
      wallets: [
        _wallet(id: 'legacy-ignored', name: 'Legacy', balance: 9),
      ],
      transactions: [
        _transaction(
          id: 'to-cold',
          walletId: 'acct-cold',
          destinationWalletId: 'acct-cold',
          amountSatoshis: 8000,
          type: TransactionType.deposit,
          timestamp: DateTime(2026, 6, 8),
        ),
        _transaction(
          id: 'from-global',
          walletId: 'acct-global',
          sourceWalletId: 'acct-global',
          amountSatoshis: 3000,
          feeSatoshis: 50,
          type: TransactionType.send,
          timestamp: DateTime(2026, 6, 9),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.walletCount, 2);
    expect(report.dominantWalletName, 'Cofre frio');
    expect(report.incomingSats, 8000);
    expect(report.outgoingSats, 3000);
    expect(report.feeSats, 50);
    expect(
      report.distribution.map((segment) => segment.label).toList(),
      ['Cofre frio', 'Carteira Global'],
    );
    expect(_bucketValue(report, 'jun.', 'acct-cold'), 8000);
    expect(_bucketValue(report, 'jun.', 'acct-global'), 3050);
  });

  test('counts unmatched in-period txs as unclassified but still in KPIs', () {
    final report = StatementReportCalculator.calculate(
      wallets: [_wallet(id: 'wallet-a', name: 'Carteira A')],
      transactions: [
        _transaction(
          id: 'orphan-credit',
          walletId: 'unknown-wallet',
          destinationWalletId: 'unknown-wallet',
          amountSatoshis: 7000,
          type: TransactionType.deposit,
          timestamp: DateTime(2026, 6, 15),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.incomingSats, 7000);
    expect(report.unclassifiedTransactionCount, 1);
    expect(report.includedTransactionCount, 1);
    expect(_bucketValue(report, 'jun.', 'wallet-a'), 0);
  });

  test('ignores placeholder addresses when matching wallets', () {
    final report = StatementReportCalculator.calculate(
      wallets: [
        _wallet(id: 'wallet-a', name: 'Carteira A', address: 'bc1qreal'),
      ],
      transactions: [
        _transaction(
          id: 'placeholder-only',
          fromAddress: 'Minha carteira',
          toAddress: 'Rede Bitcoin',
          amountSatoshis: 4000,
          type: TransactionType.send,
          timestamp: DateTime(2026, 6, 16),
        ),
      ],
      period: StatementReportPeriod.monthly,
      now: now,
    );

    expect(report.unclassifiedTransactionCount, 1);
    expect(_bucketValue(report, 'jun.', 'wallet-a'), 0);
  });
}

int _bucketValue(StatementReport report, String label, String walletId) {
  final bucket = report.buckets.firstWhere((bucket) => bucket.label == label);
  return bucket.values.firstWhere((value) => value.walletId == walletId).sats;
}

Wallet _wallet({
  required String id,
  required String name,
  String address = 'kerosene:global',
  double balance = 0.01,
}) {
  return Wallet(
    id: id,
    name: name,
    address: address,
    walletMode: 'KEROSENE',
    balance: balance,
    derivationPath: 'test-path',
    type: WalletType.nativeSegwit,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

Transaction _transaction({
  required String id,
  String fromAddress = 'external',
  String toAddress = 'external',
  String? walletId,
  String? sourceWalletId,
  String? destinationWalletId,
  required int amountSatoshis,
  int feeSatoshis = 0,
  int serviceFeeSatoshis = 0,
  TransactionStatus status = TransactionStatus.confirmed,
  required TransactionType type,
  required DateTime timestamp,
  bool isInternal = false,
}) {
  return Transaction(
    id: id,
    fromAddress: fromAddress,
    toAddress: toAddress,
    walletId: walletId,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    amountSatoshis: amountSatoshis,
    feeSatoshis: feeSatoshis,
    serviceFeeSatoshis: serviceFeeSatoshis,
    status: status,
    type: type,
    confirmations: status == TransactionStatus.confirmed ? 6 : 0,
    timestamp: timestamp,
    isInternal: isInternal,
  );
}
