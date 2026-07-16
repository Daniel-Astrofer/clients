import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_visual_tokens.dart';

/// ARB-backed labels for list/detail transaction presentation.
class TransactionPresentationCopy {
  final BuildContext context;

  const TransactionPresentationCopy(this.context);

  factory TransactionPresentationCopy.of(BuildContext context) {
    return TransactionPresentationCopy(context);
  }

  String get sent => context.tr.txListSent;
  String get received => context.tr.txListReceived;
  String get instant => context.tr.txListInstant;
  String get onchain => context.tr.activityFilterOnchain;
  String get lightning => context.tr.activityFilterLightning;
  String get cold => context.tr.activityFilterCold;
  String get link => context.tr.txListLink;
  String get deposit => context.tr.txListDeposit;
  String get withdraw => context.tr.txListWithdraw;
  String get fee => context.tr.txListFee;
  String get swap => context.tr.txListSwap;
  String get failed => context.tr.txListFailed;
  String get cancelled => context.tr.txListCancelled;
  String get needsReview => context.tr.txListNeedsReview;
  String get unconfirmed => context.tr.txListUnconfirmed;
  String get confirmed => context.tr.txListConfirmed;
  String get pending => context.tr.txListPending;
  String get confirming => context.tr.txListConfirming;
  String get toPrefix => context.tr.txListTo;
  String get fromPrefix => context.tr.txListFrom;
  String get whenLabel => context.tr.txListWhen;
  String get yourWallet => context.tr.txListYourWallet;
  String get amountLabel => context.tr.txListAmount;
  String get networkFee => context.tr.txListNetworkFee;
  String get serviceFee => context.tr.txListServiceFee;
  String get totalDebited => context.tr.txListTotalDebited;
  String get network => context.tr.txListNetwork;
  String get status => context.tr.txListStatus;
  String get confirmations => context.tr.txListConfirmations;
  String get viewDetails => context.tr.txListViewDetails;
  String get id => context.tr.txListId;
  String get paymentHash => context.tr.txListPaymentHash;
  String get block => context.tr.txListBlock;
  String get blockHash => context.tr.txListBlockHash;
  String get onchainTxid => context.tr.txListOnchainTxid;
  String get invoiceId => context.tr.txListInvoiceId;
  String get lightningInvoice => context.tr.txListLightningInvoice;
  String get externalRef => context.tr.txListExternalRef;
  String get externalTransferId => context.tr.txListExternalTransferId;
  String get externalStatus => context.tr.txListExternalStatus;
  String get externalType => context.tr.txListExternalType;
  String get sourceWallet => context.tr.txListSourceWallet;
  String get destinationWallet => context.tr.txListDestinationWallet;
  String get fromAddress => context.tr.txListFromAddress;
  String get toAddress => context.tr.txListToAddress;
  String get description => context.tr.txListDescription;
  String get internalId => context.tr.txListInternalId;
  String get amountBtc => context.tr.txListAmountBtc;
  String get reason => context.tr.txListReason;
  String get type => context.tr.txListType;
  String get dateTime => context.tr.txListDateTime;
  String get frozenUsd => context.tr.txListFrozenUsd;
  String get frozenBrl => context.tr.txListFrozenBrl;
  String get frozenEur => context.tr.txListFrozenEur;
  String get partyGlobalWallet => context.tr.txListPartyGlobalWallet;
  String get partyKeroseneWallet => context.tr.txListPartyKeroseneWallet;
  String get partyLightningInvoice => context.tr.txListPartyLightningInvoice;
  String get partyExternalAddress => context.tr.txListPartyExternalAddress;
  String get partyOffApp => context.tr.txListPartyOffApp;
  String get partyOnchainOffApp => context.tr.txListPartyOnchainOffApp;

  String railShort(TxRail rail) => switch (rail) {
        TxRail.internal => instant,
        TxRail.onchain => onchain,
        TxRail.lightning => lightning,
        TxRail.cold => cold,
      };

  String lifecycleLabel(TxLifecycle life) => switch (life) {
        TxLifecycle.pending => pending,
        TxLifecycle.confirming => confirming,
        TxLifecycle.confirmed => confirmed,
        TxLifecycle.failed => failed,
        TxLifecycle.cancelled => cancelled,
        TxLifecycle.reconciling => needsReview,
        TxLifecycle.unconfirmedExpired => unconfirmed,
      };
}

class PresentationField {
  final String key;
  final String label;
  final String value;
  final bool copyable;
  final bool technical;

  const PresentationField({
    required this.key,
    required this.label,
    required this.value,
    this.copyable = false,
    this.technical = false,
  });
}

/// Single presentation model for Home / Extrato list rows and detail primary.
final class TransactionPresentation {
  final String id;
  final TransactionAxes axes;
  final String title;
  final String subtitle;
  final String tertiary;
  final String statusLabel;
  final IconData icon;
  final Color cardBackground;
  final Color cardBorder;
  final String primaryAmountLabel;
  final List<PresentationField> expandedFields;
  final List<PresentationField> technicalFields;

  const TransactionPresentation({
    required this.id,
    required this.axes,
    required this.title,
    required this.subtitle,
    required this.tertiary,
    required this.statusLabel,
    required this.icon,
    required this.cardBackground,
    required this.cardBorder,
    required this.primaryAmountLabel,
    required this.expandedFields,
    required this.technicalFields,
  });

  factory TransactionPresentation.fromTransaction(
    BuildContext context,
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
    required Currency displayCurrency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    Locale? appLocale,
  }) {
    final copy = TransactionPresentationCopy.of(context);
    final axes = TransactionAxes.classify(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    final title = _title(copy, axes);
    final counterparty = _counterparty(
      context,
      tx,
      axes: axes,
      wallets: wallets,
      accounts: accounts,
    );
    final subtitle = switch (axes.direction) {
      TxDirection.outgoing => '${copy.toPrefix} $counterparty',
      TxDirection.incoming => '${copy.fromPrefix} $counterparty',
      TxDirection.neutral => counterparty,
    };

    final includeFeesInDebit =
        tx.isDebit && (tx.showsNetworkFee || tx.showsServiceFee);
    final amount = MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: tx.signedDisplayAmountBTC,
      currency: displayCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: includeFeesInDebit ? null : tx.displayAmountUsd,
      displayAmountEur: includeFeesInDebit ? null : tx.displayAmountEur,
      displayAmountBrl: includeFeesInDebit ? null : tx.displayAmountBrl,
      displayBtcUsd: tx.displayBtcUsd,
      displayBtcEur: tx.displayBtcEur,
      displayBtcBrl: tx.displayBtcBrl,
      signed: true,
      appLocale: appLocale,
    );

    final principalLabel = MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: tx.signedAmountBTC,
      currency: displayCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: tx.displayAmountUsd,
      displayAmountEur: tx.displayAmountEur,
      displayAmountBrl: tx.displayAmountBrl,
      displayBtcUsd: tx.displayBtcUsd,
      displayBtcEur: tx.displayBtcEur,
      displayBtcBrl: tx.displayBtcBrl,
      signed: true,
      appLocale: appLocale,
    );

    final from = resolveTransactionFromParty(
      tx,
      wallets: wallets,
      accounts: accounts,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final to = resolveTransactionToParty(
      tx,
      wallets: wallets,
      accounts: accounts,
      compactHash: true,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final own = resolveOwnWalletLabel(
      tx,
      wallets: wallets,
      accounts: accounts,
      languageCode: Localizations.localeOf(context).languageCode,
    );

    final expanded = <PresentationField>[
      PresentationField(
        key: 'when',
        label: copy.whenLabel,
        value: AppDateTime.formatRelativeWithClock(context, tx.timestamp),
      ),
      PresentationField(
        key: 'wallet',
        label: copy.yourWallet,
        value: own.isEmpty ? '—' : own,
      ),
      PresentationField(
        key: 'from',
        label: copy.fromPrefix,
        value: from.isEmpty ? '—' : from,
      ),
      PresentationField(
        key: 'to',
        label: copy.toPrefix,
        value: to.isEmpty ? '—' : to,
        copyable: looksLikeOnchainAddress(to),
      ),
      PresentationField(
        key: 'amount',
        label: copy.amountLabel,
        value: principalLabel,
      ),
    ];

    if (tx.showsNetworkFee) {
      expanded.add(
        PresentationField(
          key: 'network-fee',
          label: copy.networkFee,
          value: formatSatsAsBtc(tx.feeSatoshis),
        ),
      );
    }
    if (tx.showsServiceFee) {
      expanded.add(
        PresentationField(
          key: 'service-fee',
          label: copy.serviceFee,
          value: formatSatsAsBtc(tx.serviceFeeSatoshis),
        ),
      );
    }
    if (includeFeesInDebit) {
      expanded.add(
        PresentationField(
          key: 'total',
          label: copy.totalDebited,
          value: amount,
        ),
      );
    }

    expanded.addAll([
      PresentationField(
        key: 'network',
        label: copy.network,
        value: copy.railShort(axes.rail),
      ),
      PresentationField(
        key: 'status',
        label: copy.status,
        value: copy.lifecycleLabel(axes.lifecycle),
      ),
    ]);

    if (tx.showsOnchainConfirmations) {
      final conf = tx.confirmations >= tx.onchainConfirmationTarget
          ? '${tx.confirmations}+'
          : '${tx.confirmations}/${tx.onchainConfirmationTarget}';
      expanded.add(
        PresentationField(
          key: 'confirmations',
          label: copy.confirmations,
          value: conf,
        ),
      );
    }

    final technical = <PresentationField>[];
    final txid = (tx.blockchainTxid ?? tx.id).trim();
    if (txid.isNotEmpty) {
      technical.add(
        PresentationField(
          key: 'txid',
          label: copy.id,
          value: txid,
          copyable: true,
          technical: true,
        ),
      );
    }
    final hash = (tx.paymentHash ?? '').trim();
    if (hash.isNotEmpty) {
      technical.add(
        PresentationField(
          key: 'payment-hash',
          label: copy.paymentHash,
          value: hash,
          copyable: true,
          technical: true,
        ),
      );
    }
    if ((tx.blockHeight ?? 0) > 0) {
      technical.add(
        PresentationField(
          key: 'block',
          label: copy.block,
          value: '#${tx.blockHeight}',
          technical: true,
        ),
      );
    }

    return TransactionPresentation(
      id: tx.id,
      axes: axes,
      title: title,
      subtitle: subtitle,
      tertiary: AppDateTime.formatRelative(context, tx.timestamp),
      statusLabel: copy.lifecycleLabel(axes.lifecycle),
      icon: TransactionVisualTokens.iconFor(axes),
      cardBackground: TransactionVisualTokens.backgroundFor(axes.variant),
      cardBorder: TransactionVisualTokens.borderFor(axes.variant),
      primaryAmountLabel: amount,
      expandedFields: expanded,
      technicalFields: technical,
    );
  }

  static String _title(
    TransactionPresentationCopy copy,
    TransactionAxes axes,
  ) {
    if (axes.lifecycle == TxLifecycle.cancelled) return copy.cancelled;
    if (axes.lifecycle == TxLifecycle.failed) return copy.failed;
    if (axes.lifecycle == TxLifecycle.unconfirmedExpired) {
      return copy.unconfirmed;
    }
    if (axes.lifecycle == TxLifecycle.reconciling) return copy.needsReview;

    if (axes.product == TxProduct.fee) return copy.fee;
    if (axes.product == TxProduct.swap) return copy.swap;
    if (axes.product == TxProduct.deposit) {
      return '${copy.deposit} · ${copy.railShort(axes.rail)}';
    }
    if (axes.product == TxProduct.withdraw) {
      return '${copy.withdraw} · ${copy.railShort(axes.rail)}';
    }
    if (axes.product == TxProduct.paymentLink) {
      final action = axes.direction == TxDirection.incoming
          ? copy.received
          : copy.sent;
      return '$action · ${copy.link}';
    }

    final action =
        axes.direction == TxDirection.incoming ? copy.received : copy.sent;
    return '$action · ${copy.railShort(axes.rail)}';
  }

  static String _counterparty(
    BuildContext context,
    Transaction tx, {
    required TransactionAxes axes,
    required List<Wallet> wallets,
    required List<BitcoinAccount> accounts,
  }) {
    final lang = Localizations.localeOf(context).languageCode;
    if (axes.direction == TxDirection.incoming) {
      final from = resolveTransactionFromParty(
        tx,
        wallets: wallets,
        accounts: accounts,
        languageCode: lang,
      );
      return from.isEmpty ? '—' : from;
    }
    if (axes.direction == TxDirection.outgoing) {
      final to = resolveTransactionToParty(
        tx,
        wallets: wallets,
        accounts: accounts,
        compactHash: true,
        languageCode: lang,
      );
      return to.isEmpty ? '—' : to;
    }
    final own = resolveOwnWalletLabel(
      tx,
      wallets: wallets,
      accounts: accounts,
      languageCode: lang,
    );
    return own.isEmpty ? '—' : own;
  }
}
