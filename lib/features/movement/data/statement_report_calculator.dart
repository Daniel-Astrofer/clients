import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/statement_report.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';

class StatementReportCalculator {
  static const int _satsPerBtc = 100000000;

  /// Soft signal that remote history is capped (page size).
  static const int partialHistoryThreshold = 50;

  const StatementReportCalculator._();

  static StatementReport calculate({
    required List<Transaction> transactions,
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
    required StatementReportPeriod period,
    DateTime? now,
    String locale = 'pt',
    String emptyWalletName = 'Sem carteiras',
  }) {
    final effectiveNow = now ?? DateTime.now();
    final walletInsights = _walletInsights(
      wallets: wallets,
      accounts: accounts,
      emptyWalletName: emptyWalletName,
    );
    final ranges = _bucketRanges(
      accounts: accounts,
      wallets: wallets,
      period: period,
      now: effectiveNow,
      locale: locale,
    );
    final reportStart = ranges.first.start;
    final reportEnd = ranges.last.end;

    // Only collapse everything into one wallet when we truly have a single
    // known account/wallet with no identity keys (edge empty case).
    final countAllTransactionsAsSingleWallet = walletInsights.length == 1 &&
        walletInsights.first.matchKeys.isEmpty &&
        walletInsights.first.id == 'empty';

    final usableTransactions = transactions
        .where((tx) =>
            tx.status != TransactionStatus.failed &&
            tx.status != TransactionStatus.cancelled &&
            tx.status != TransactionStatus.reconciling)
        .toList(growable: false);

    final buckets = ranges.map((range) {
      return StatementMovementBucket(
        label: range.label,
        start: range.start,
        end: range.end,
        values: [
          for (final wallet in walletInsights)
            StatementWalletBucketValue(
              walletId: wallet.id,
              sats: _walletVolumeForRange(
                wallet,
                usableTransactions,
                start: range.start,
                end: range.end,
                fallbackToWallet: countAllTransactionsAsSingleWallet,
              ),
            ),
        ],
      );
    }).toList(growable: false);

    var incoming = 0;
    var outgoing = 0;
    var fees = 0;
    var serviceFees = 0;
    var internalTransfers = 0;
    var includedTransactions = 0;
    var ignoredFailedTransactions = 0;
    var ignoredOutOfPeriodTransactions = 0;
    var unclassifiedTransactions = 0;

    for (final tx in transactions) {
      final local = tx.timestamp.toLocal();
      if (local.isBefore(reportStart) || !local.isBefore(reportEnd)) {
        ignoredOutOfPeriodTransactions += 1;
        continue;
      }
      if (tx.status == TransactionStatus.failed ||
          tx.status == TransactionStatus.cancelled ||
          tx.status == TransactionStatus.reconciling) {
        ignoredFailedTransactions += 1;
        continue;
      }

      final classification = _classifyTransaction(
        tx,
        walletInsights,
        fallbackToWallet: countAllTransactionsAsSingleWallet,
      );

      // Global KPIs count every usable in-period movement (honest totals).
      includedTransactions += 1;
      if (!classification.belongsToKnownWallet &&
          !countAllTransactionsAsSingleWallet) {
        unclassifiedTransactions += 1;
      }

      final amount = tx.amountSatoshis.abs();
      final fee = tx.feeSatoshis.abs();
      final serviceFee = tx.serviceFeeSatoshis.abs();

      if (classification.isInternalBetweenKnownWallets ||
          (tx.isInternal && classification.belongsToKnownWallet)) {
        if (classification.isInternalBetweenKnownWallets) {
          internalTransfers += amount;
          fees += fee;
          serviceFees += serviceFee;
          continue;
        }
      }

      if (tx.isCredit || classification.destinationMatchesKnownWallet) {
        incoming += amount;
        continue;
      }

      if (tx.isDebit || classification.sourceMatchesKnownWallet) {
        outgoing += amount;
        fees += fee;
        serviceFees += serviceFee;
        continue;
      }

      // Unmatched but still in-period: attribute by direction flags.
      if (tx.isCredit) {
        incoming += amount;
      } else if (tx.isDebit) {
        outgoing += amount;
        fees += fee;
        serviceFees += serviceFee;
      }
    }

    final totalBalance = walletInsights.fold<int>(
      0,
      (sum, wallet) => sum + math.max(0, wallet.balanceSats),
    );
    final dominant = walletInsights.reduce((a, b) {
      if (b.balanceSats != a.balanceSats) {
        return b.balanceSats > a.balanceSats ? b : a;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase()) <= 0 ? a : b;
    });
    final distribution = [
      for (final wallet in walletInsights)
        if (wallet.id != 'empty' || wallet.balanceSats > 0)
          StatementDistributionSegment(
            walletId: wallet.id,
            label: wallet.name,
            sats: wallet.balanceSats,
            visualSats: totalBalance > 0 ? math.max(0, wallet.balanceSats) : 0,
            percent:
                totalBalance <= 0 ? 0 : wallet.balanceSats / totalBalance * 100,
          ),
    ];
    // Keep empty distribution honest.
    final safeDistribution = distribution.isEmpty
        ? [
            StatementDistributionSegment(
              walletId: dominant.id,
              label: dominant.name,
              sats: 0,
              visualSats: 0,
              percent: 0,
            ),
          ]
        : distribution;

    final rawAxisMax = buckets.fold<int>(
      0,
      (maxValue, bucket) => math.max(
        maxValue,
        bucket.values.fold<int>(
          0,
          (bucketMax, value) => math.max(bucketMax, value.sats),
        ),
      ),
    );

    final isPartial = _isPartialHistory(
      transactions: transactions,
      reportStart: reportStart,
    );

    final net = incoming - outgoing - fees - serviceFees;

    return StatementReport(
      wallets: walletInsights,
      buckets: buckets,
      distribution: safeDistribution,
      incomingSats: incoming,
      outgoingSats: outgoing,
      feeSats: fees,
      serviceFeeSats: serviceFees,
      internalTransferSats: internalTransfers,
      netSats: net,
      axisMaxSats: _niceAxisMax(rawAxisMax),
      totalBalanceSats: totalBalance,
      dominantWalletName: dominant.name,
      isPartial: isPartial,
      walletCount: walletInsights.where((w) => w.id != 'empty').length,
      loadedTransactionCount: transactions.length,
      includedTransactionCount: includedTransactions,
      ignoredFailedTransactionCount: ignoredFailedTransactions,
      ignoredOutOfPeriodTransactionCount: ignoredOutOfPeriodTransactions,
      unclassifiedTransactionCount: unclassifiedTransactions,
      periodStart: reportStart,
      periodEnd: reportEnd,
    );
  }

  static bool _isPartialHistory({
    required List<Transaction> transactions,
    required DateTime reportStart,
  }) {
    if (transactions.length >= partialHistoryThreshold) return true;
    if (transactions.isEmpty) return false;
    DateTime? oldest;
    for (final tx in transactions) {
      final t = tx.timestamp.toLocal();
      if (oldest == null || t.isBefore(oldest)) oldest = t;
    }
    // If the oldest loaded tx is still after the report window start, we likely
    // do not have full history for the selected period.
    return oldest != null && oldest.isAfter(reportStart);
  }

  static List<StatementWalletInsight> _walletInsights({
    required List<Wallet> wallets,
    required List<BitcoinAccount> accounts,
    required String emptyWalletName,
  }) {
    final activeAccounts =
        accounts.where((account) => account.isActive).toList(growable: false);

    if (activeAccounts.isNotEmpty) {
      final insights = [
        for (final account in activeAccounts)
          StatementWalletInsight(
            id: account.id,
            name: _accountDisplayName(account),
            matchKeys: _accountMatchKeys(account),
            balanceSats: math.max(0, account.primarySats),
          ),
      ]..sort((a, b) {
          final balance = b.balanceSats.compareTo(a.balanceSats);
          if (balance != 0) return balance;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return insights;
    }

    final source = wallets.where((wallet) => wallet.isActive).toList();
    final displayWallets =
        source.isNotEmpty ? source : List<Wallet>.from(wallets);
    displayWallets.sort((a, b) {
      final balance = b.balance.compareTo(a.balance);
      if (balance != 0) return balance;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (displayWallets.isEmpty) {
      return [
        StatementWalletInsight(
          id: 'empty',
          name: emptyWalletName,
          matchKeys: const {},
          balanceSats: 0,
        ),
      ];
    }

    return [
      for (final wallet in displayWallets)
        StatementWalletInsight(
          id: wallet.id,
          name: wallet.name.trim().isEmpty ? emptyWalletName : wallet.name,
          matchKeys: _walletMatchKeys(wallet),
          balanceSats: _btcToSats(wallet.balance),
        ),
    ];
  }

  static String _accountDisplayName(BitcoinAccount account) {
    final label = account.label.trim();
    if (label.isNotEmpty) return label;
    return account.custodyDisplayLabel;
  }

  static Set<String> _accountMatchKeys(BitcoinAccount account) {
    return {
      account.id,
      account.label,
      account.coldWalletId ?? '',
      account.custody,
      account.type,
      if (account.isInternal) 'carteira global',
      if (account.isInternal) 'conta assegurada',
    }
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static Set<String> _walletMatchKeys(Wallet wallet) {
    return {
      wallet.id,
      wallet.name,
      wallet.address,
      wallet.cardHolderName,
      wallet.cardNumberSuffix,
    }
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static List<({DateTime start, DateTime end, String label})> _bucketRanges({
    required List<BitcoinAccount> accounts,
    required List<Wallet> wallets,
    required StatementReportPeriod period,
    required DateTime now,
    required String locale,
  }) {
    final localNow = now.toLocal();
    DateTime? earliest;
    for (final wallet in wallets) {
      final created = wallet.createdAt.toLocal();
      if (earliest == null || created.isBefore(earliest)) earliest = created;
    }
    // Accounts have no createdAt; fall back to year start if needed.
    final createdAt = earliest ?? DateTime(localNow.year, localNow.month);

    switch (period) {
      case StatementReportPeriod.weekly:
        final currentWeek = _weekStart(localNow);
        final firstWeek = _weekStart(createdAt);
        final ytdWeek = _weekStart(DateTime(localNow.year));
        // Cap at 12 weeks for readability.
        final capWeek = currentWeek.subtract(const Duration(days: 7 * 11));
        final start = _maxDate(
          firstWeek.isAfter(ytdWeek) ? firstWeek : ytdWeek,
          capWeek,
        );
        final ranges = <({DateTime start, DateTime end, String label})>[];
        for (var week = start;
            !week.isAfter(currentWeek);
            week = week.add(const Duration(days: 7))) {
          ranges.add((
            start: week,
            end: week.add(const Duration(days: 7)),
            label: DateFormat.MMMd(locale).format(week),
          ));
        }
        return ranges.isEmpty
            ? [
                (
                  start: currentWeek,
                  end: currentWeek.add(const Duration(days: 7)),
                  label: DateFormat.MMMd(locale).format(currentWeek),
                )
              ]
            : ranges;
      case StatementReportPeriod.annual:
        final currentMonth = DateTime(localNow.year, localNow.month);
        final firstMonth = DateTime(createdAt.year, createdAt.month);
        final start = _maxDate(
          firstMonth,
          DateTime(currentMonth.year, currentMonth.month - 11),
        );
        return _monthRanges(start, currentMonth, locale);
      case StatementReportPeriod.monthly:
        final currentMonth = DateTime(localNow.year, localNow.month);
        final firstMonth = DateTime(createdAt.year, createdAt.month);
        final start = _maxDate(
          firstMonth,
          DateTime(currentMonth.year, currentMonth.month - 5),
        );
        return _monthRanges(start, currentMonth, locale);
    }
  }

  static List<({DateTime start, DateTime end, String label})> _monthRanges(
    DateTime start,
    DateTime currentMonth,
    String locale,
  ) {
    final ranges = <({DateTime start, DateTime end, String label})>[];
    for (var month = DateTime(start.year, start.month);
        !month.isAfter(currentMonth);
        month = DateTime(month.year, month.month + 1)) {
      ranges.add((
        start: month,
        end: DateTime(month.year, month.month + 1),
        label: DateFormat.MMM(locale).format(month),
      ));
    }
    return ranges;
  }

  static int _walletVolumeForRange(
    StatementWalletInsight wallet,
    List<Transaction> transactions, {
    required DateTime start,
    required DateTime end,
    required bool fallbackToWallet,
  }) {
    var total = 0;
    for (final tx in transactions) {
      final local = tx.timestamp.toLocal();
      if (local.isBefore(start) || !local.isBefore(end)) continue;
      final delta = _walletDelta(
        wallet,
        tx,
        fallbackToWallet: fallbackToWallet,
      );
      total += delta.abs();
    }
    return total;
  }

  static int _walletDelta(
    StatementWalletInsight wallet,
    Transaction tx, {
    required bool fallbackToWallet,
  }) {
    final amount = tx.amountSatoshis.abs();
    final debitAmount =
        amount + tx.feeSatoshis.abs() + tx.serviceFeeSatoshis.abs();
    final walletMatches = _matchesWallet(wallet, [tx.walletId]);
    final sourceMatches = _matchesWallet(wallet, [
      tx.sourceWalletId,
      // Avoid matching generic placeholders as wallet identity.
      if (!_isPlaceholder(tx.fromAddress)) tx.fromAddress,
    ]);
    final destinationMatches = _matchesWallet(wallet, [
      tx.destinationWalletId,
      if (!_isPlaceholder(tx.toAddress)) tx.toAddress,
    ]);
    final matched = walletMatches || sourceMatches || destinationMatches;

    if (!matched && !fallbackToWallet) return 0;
    if (tx.isInternal) {
      if (sourceMatches && !destinationMatches) return -debitAmount;
      if (destinationMatches && !sourceMatches) return amount;
    }
    if (tx.isCredit &&
        (destinationMatches || walletMatches || fallbackToWallet)) {
      return amount;
    }
    if (tx.isDebit && (sourceMatches || walletMatches || fallbackToWallet)) {
      return -debitAmount;
    }
    return 0;
  }

  static bool _isPlaceholder(String? value) {
    final lower = (value ?? '').trim().toLowerCase();
    if (lower.isEmpty) return true;
    return lower == 'minha carteira' ||
        lower == 'my wallet' ||
        lower == 'rede bitcoin' ||
        lower == 'bitcoin network' ||
        lower == 'carteira kerosene' ||
        lower == 'destino' ||
        lower == 'origem';
  }

  static _TransactionClassification _classifyTransaction(
    Transaction tx,
    List<StatementWalletInsight> wallets, {
    required bool fallbackToWallet,
  }) {
    if (fallbackToWallet) {
      return const _TransactionClassification(
        belongsToKnownWallet: true,
        sourceMatchesKnownWallet: true,
        destinationMatchesKnownWallet: true,
        isInternalBetweenKnownWallets: false,
      );
    }

    var walletMatches = false;
    var sourceMatches = false;
    var destinationMatches = false;
    for (final wallet in wallets) {
      walletMatches = walletMatches || _matchesWallet(wallet, [tx.walletId]);
      sourceMatches = sourceMatches ||
          _matchesWallet(wallet, [
            tx.sourceWalletId,
            if (!_isPlaceholder(tx.fromAddress)) tx.fromAddress,
          ]);
      destinationMatches = destinationMatches ||
          _matchesWallet(wallet, [
            tx.destinationWalletId,
            if (!_isPlaceholder(tx.toAddress)) tx.toAddress,
          ]);
    }
    return _TransactionClassification(
      belongsToKnownWallet:
          walletMatches || sourceMatches || destinationMatches,
      sourceMatchesKnownWallet: sourceMatches || (tx.isDebit && walletMatches),
      destinationMatchesKnownWallet:
          destinationMatches || (tx.isCredit && walletMatches),
      isInternalBetweenKnownWallets:
          tx.isInternal && sourceMatches && destinationMatches,
    );
  }

  static bool _matchesWallet(
    StatementWalletInsight wallet,
    List<String?> candidates,
  ) {
    for (final candidate in candidates) {
      final normalized = candidate?.trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) continue;
      if (wallet.matchKeys.contains(normalized)) return true;
    }
    return false;
  }

  static DateTime _weekStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day - local.weekday + 1);
  }

  static DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static int _btcToSats(double value) => (value * _satsPerBtc).round();

  static int _niceAxisMax(int raw) {
    if (raw <= 0) return 1000;
    final magnitude = math.pow(10, raw.toString().length - 1).toInt();
    final normalized = raw / magnitude;
    final multiplier = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;
    return multiplier * magnitude;
  }
}

class _TransactionClassification {
  final bool belongsToKnownWallet;
  final bool sourceMatchesKnownWallet;
  final bool destinationMatchesKnownWallet;
  final bool isInternalBetweenKnownWallets;

  const _TransactionClassification({
    required this.belongsToKnownWallet,
    required this.sourceMatchesKnownWallet,
    required this.destinationMatchesKnownWallet,
    required this.isInternalBetweenKnownWallets,
  });
}
