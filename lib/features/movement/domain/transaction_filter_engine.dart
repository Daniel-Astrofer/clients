import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';

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
  cancelled,
}

/// Pure filter predicates over classified transactions.
abstract final class TransactionFilterEngine {
  static bool matchesActivity(
    Transaction tx,
    ActivityFilter filter, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    final axes = TransactionAxes.classify(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    return matchesAxes(axes, filter);
  }

  static bool matchesAxes(TransactionAxes axes, ActivityFilter filter) {
    return switch (filter) {
      ActivityFilter.all => axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.incoming =>
        axes.direction == TxDirection.incoming &&
            axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.outgoing =>
        axes.direction == TxDirection.outgoing &&
            axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.instant =>
        axes.rail == TxRail.internal &&
            axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.onchain =>
        axes.rail == TxRail.onchain &&
            axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.lightning =>
        axes.rail == TxRail.lightning &&
            axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.cold =>
        axes.rail == TxRail.cold && axes.lifecycle != TxLifecycle.cancelled,
      ActivityFilter.inProgress =>
        axes.lifecycle == TxLifecycle.pending ||
            axes.lifecycle == TxLifecycle.confirming ||
            axes.lifecycle == TxLifecycle.reconciling,
      ActivityFilter.problems =>
        axes.lifecycle == TxLifecycle.failed ||
            axes.lifecycle == TxLifecycle.unconfirmedExpired,
      ActivityFilter.cancelled => axes.lifecycle == TxLifecycle.cancelled,
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
          ),
        )
        .toList(growable: false);
  }
}
