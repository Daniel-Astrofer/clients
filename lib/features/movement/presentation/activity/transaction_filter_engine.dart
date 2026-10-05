import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';

/// Activity filters shared by Home and Extrato.
enum ActivityFilter {
  all,
  incoming,
  outgoing,
  instant, // internal rail
  onchain,
  lightning,
  cold,
  inProgress, // pending + confirming + reconciling
  problems, // failed + unconfirmedExpired
  /// Cancelled but not yet archived (still visible in main flow until opened).
  cancelled,

  /// Local archive after user opens a cancelled item.
  archived,
}

/// Pure filter predicates over classified transactions.
abstract final class TransactionFilterEngine {
  static bool matchesActivity(
    Transaction tx,
    ActivityFilter filter, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
    Set<String> archivedIds = const {},
  }) {
    final axes = TransactionAxes.classify(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    final archived = archivedIds.contains(tx.id.trim());
    return matchesAxes(
      axes,
      filter,
      isArchived: archived,
    );
  }

  static bool matchesAxes(
    TransactionAxes axes,
    ActivityFilter filter, {
    bool isArchived = false,
  }) {
    // Archive is a local bucket: only visible under [ActivityFilter.archived].
    if (filter == ActivityFilter.archived) {
      return isArchived;
    }
    if (isArchived) {
      return false;
    }

    return switch (filter) {
      // Cancelled stays in the global feed until the user opens it (then archive).
      ActivityFilter.all => true,
      ActivityFilter.incoming => axes.direction == TxDirection.incoming,
      ActivityFilter.outgoing => axes.direction == TxDirection.outgoing,
      ActivityFilter.instant => axes.rail == TxRail.internal,
      ActivityFilter.onchain => axes.rail == TxRail.onchain,
      ActivityFilter.lightning => axes.rail == TxRail.lightning,
      ActivityFilter.cold => axes.rail == TxRail.cold,
      ActivityFilter.inProgress => axes.lifecycle == TxLifecycle.pending ||
          axes.lifecycle == TxLifecycle.confirming ||
          axes.lifecycle == TxLifecycle.reconciling,
      ActivityFilter.problems => axes.lifecycle == TxLifecycle.failed ||
          axes.lifecycle == TxLifecycle.unconfirmedExpired,
      ActivityFilter.cancelled => axes.lifecycle == TxLifecycle.cancelled,
      ActivityFilter.archived => isArchived,
    };
  }

  /// Wallet scope: match **canonical ids only** (no free-text name matching).
  static bool touchesWallet(
    Transaction tx, {
    required Wallet wallet,
    List<BitcoinAccount> accounts = const [],
  }) {
    final ids = <String>{
      wallet.id.trim(),
      if ((wallet.address).trim().isNotEmpty) wallet.address.trim(),
    };
    for (final account in accounts) {
      final matchesWallet = account.id == wallet.id ||
          account.label == wallet.name ||
          (account.coldWalletId ?? '') == wallet.id;
      if (!matchesWallet) continue;
      if (account.id.trim().isNotEmpty) ids.add(account.id.trim());
      final cold = (account.coldWalletId ?? '').trim();
      if (cold.isNotEmpty) ids.add(cold);
    }
    ids.removeWhere((e) => e.isEmpty);

    final candidates = <String?>[
      tx.walletId,
      tx.sourceWalletId,
      tx.destinationWalletId,
    ];
    for (final c in candidates) {
      final v = (c ?? '').trim();
      if (v.isNotEmpty && ids.contains(v)) return true;
    }
    // Registered deposit address only (not arbitrary string match on names).
    final addr = wallet.address.trim();
    if (addr.isNotEmpty) {
      if (tx.fromAddress.trim() == addr || tx.toAddress.trim() == addr) {
        return true;
      }
    }
    return false;
  }

  static List<Transaction> apply({
    required List<Transaction> source,
    required ActivityFilter activity,
    Wallet? scopeWallet,
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
    Set<String> archivedIds = const {},
  }) {
    Iterable<Transaction> rows = source;
    if (scopeWallet != null) {
      rows = rows.where(
        (tx) => touchesWallet(
          tx,
          wallet: scopeWallet,
          accounts: accounts,
        ),
      );
    }
    return rows
        .where(
          (tx) => matchesActivity(
            tx,
            activity,
            wallets: wallets,
            accounts: accounts,
            archivedIds: archivedIds,
          ),
        )
        .toList(growable: false);
  }
}
