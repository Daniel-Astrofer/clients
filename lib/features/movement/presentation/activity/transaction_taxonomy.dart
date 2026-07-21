import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/transaction_party_display.dart';

/// Direction of funds relative to the signed-in user.
enum TxDirection { incoming, outgoing, neutral }

/// Settlement rail (how value moved).
enum TxRail { internal, onchain, lightning, cold }

/// Product surface that originated the movement.
enum TxProduct {
  transfer,
  paymentLink,
  deposit,
  withdraw,
  fee,
  swap,
  other,
}

/// Lifecycle for filters, rings, and status labels.
enum TxLifecycle {
  pending,
  confirming,
  confirmed,
  failed,
  cancelled,
  reconciling,
  unconfirmedExpired,
}

/// Rich visual variant for home cards — more than rail-only (3–4 colors).
///
/// Combines rail × direction × product × lifecycle so cards are distinguishable.
enum TxVisualVariant {
  internalIn,
  internalOut,
  onchainIn,
  onchainOut,
  lightningIn,
  lightningOut,
  coldIn,
  coldOut,
  paymentLinkIn,
  paymentLinkOut,
  fee,
  swap,
  failed,
  cancelled,
  reconciling,
  pendingNeutral,
}

/// Pure classification of a [Transaction] for filters + presentation.
final class TransactionAxes {
  final TxDirection direction;
  final TxRail rail;
  final TxProduct product;
  final TxLifecycle lifecycle;
  final TxVisualVariant variant;

  const TransactionAxes({
    required this.direction,
    required this.rail,
    required this.product,
    required this.lifecycle,
    required this.variant,
  });

  static TransactionAxes classify(
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    final direction = _direction(tx);
    final product = _product(tx);
    final rail = _rail(tx, wallets: wallets, accounts: accounts);
    final lifecycle = _lifecycle(tx);
    final variant = _variant(
      direction: direction,
      rail: rail,
      product: product,
      lifecycle: lifecycle,
    );
    return TransactionAxes(
      direction: direction,
      rail: rail,
      product: product,
      lifecycle: lifecycle,
      variant: variant,
    );
  }

  static TxDirection _direction(Transaction tx) {
    if (tx.type == TransactionType.fee || tx.type == TransactionType.swap) {
      return TxDirection.neutral;
    }
    if (tx.isCredit) return TxDirection.incoming;
    if (tx.isDebit) return TxDirection.outgoing;
    return TxDirection.neutral;
  }

  static TxProduct _product(Transaction tx) {
    if (tx.isPaymentLink) return TxProduct.paymentLink;
    if (tx.type == TransactionType.deposit) return TxProduct.deposit;
    if (tx.type == TransactionType.withdrawal) return TxProduct.withdraw;
    if (tx.type == TransactionType.fee) return TxProduct.fee;
    if (tx.type == TransactionType.swap) return TxProduct.swap;
    if (tx.type == TransactionType.send ||
        tx.type == TransactionType.receive) {
      return TxProduct.transfer;
    }
    return TxProduct.other;
  }

  static TxRail _rail(
    Transaction tx, {
    required List<Wallet> wallets,
    required List<BitcoinAccount> accounts,
  }) {
    final network = resolveTransactionNetwork(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    return switch (network) {
      TransactionNetwork.internal ||
      TransactionNetwork.paymentLinkInternal =>
        TxRail.internal,
      TransactionNetwork.lightning => TxRail.lightning,
      TransactionNetwork.cold => TxRail.cold,
      TransactionNetwork.onchain ||
      TransactionNetwork.paymentLinkOnchain ||
      TransactionNetwork.unknown =>
        TxRail.onchain,
    };
  }

  static TxLifecycle _lifecycle(Transaction tx) {
    if (tx.isUnconfirmedExpired) return TxLifecycle.unconfirmedExpired;
    // Prefer displayStatus so USER_CANCELLED (FAILED+code) classifies as cancelled.
    return switch (tx.displayStatus) {
      TransactionStatus.pending => TxLifecycle.pending,
      TransactionStatus.confirming => TxLifecycle.confirming,
      TransactionStatus.confirmed => TxLifecycle.confirmed,
      TransactionStatus.failed => TxLifecycle.failed,
      TransactionStatus.cancelled => TxLifecycle.cancelled,
      TransactionStatus.reconciling => TxLifecycle.reconciling,
    };
  }

  static TxVisualVariant _variant({
    required TxDirection direction,
    required TxRail rail,
    required TxProduct product,
    required TxLifecycle lifecycle,
  }) {
    if (lifecycle == TxLifecycle.cancelled) return TxVisualVariant.cancelled;
    if (lifecycle == TxLifecycle.failed ||
        lifecycle == TxLifecycle.unconfirmedExpired) {
      return TxVisualVariant.failed;
    }
    if (lifecycle == TxLifecycle.reconciling) {
      return TxVisualVariant.reconciling;
    }
    if (product == TxProduct.fee) return TxVisualVariant.fee;
    if (product == TxProduct.swap) return TxVisualVariant.swap;
    if (product == TxProduct.paymentLink) {
      return direction == TxDirection.incoming
          ? TxVisualVariant.paymentLinkIn
          : TxVisualVariant.paymentLinkOut;
    }
    return switch (rail) {
      TxRail.internal => direction == TxDirection.incoming
          ? TxVisualVariant.internalIn
          : TxVisualVariant.internalOut,
      TxRail.onchain => direction == TxDirection.incoming
          ? TxVisualVariant.onchainIn
          : TxVisualVariant.onchainOut,
      TxRail.lightning => direction == TxDirection.incoming
          ? TxVisualVariant.lightningIn
          : TxVisualVariant.lightningOut,
      TxRail.cold => direction == TxDirection.incoming
          ? TxVisualVariant.coldIn
          : TxVisualVariant.coldOut,
    };
  }
}
