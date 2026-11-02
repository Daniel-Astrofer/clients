import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_party_display.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_visual_tokens.dart';

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

  /// On-chain confirmation progress (only for [key] == confirmations).
  final int? progressCurrent;
  final int? progressTarget;

  const PresentationField({
    required this.key,
    required this.label,
    required this.value,
    this.copyable = false,
    this.technical = false,
    this.progressCurrent,
    this.progressTarget,
  });

  bool get hasConfirmationProgress =>
      progressCurrent != null && progressTarget != null && progressTarget! > 0;
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

  /// Compact expand rows for Home / stacked list (curated by rail × product).
  final List<PresentationField> listExpandFields;

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
    this.listExpandFields = const [],
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
    int btcDecimalPlaces = 8,

    /// When false, skips dossier / expand field lists (home row scan path).
    bool includeExpandPayload = true,
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
    final recordedFiat = switch (displayCurrency) {
      Currency.usd => tx.displayAmountUsd,
      Currency.eur => tx.displayAmountEur,
      Currency.brl => tx.displayAmountBrl,
      Currency.btc => null,
    };
    final amount = MoneyDisplay.formatOperationAmount(
        satoshis:
            tx.isDebit ? -tx.signedDisplaySatoshis : tx.signedDisplaySatoshis,
        currency: displayCurrency,
        recordedFiat: includeFeesInDebit ? null : recordedFiat,
        signed: true,
        appLocale: appLocale);
    final principalLabel = MoneyDisplay.formatOperationAmount(
        satoshis: tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis,
        currency: displayCurrency,
        recordedFiat: recordedFiat,
        signed: true,
        appLocale: appLocale);

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

    final expanded = includeExpandPayload
        ? _buildExpandedFields(
            context: context,
            copy: copy,
            tx: tx,
            axes: axes,
            from: from,
            to: to,
            own: own,
            principalLabel: principalLabel,
            amount: amount,
            includeFeesInDebit: includeFeesInDebit,
          )
        : const <PresentationField>[];

    final technical = includeExpandPayload
        ? _buildTechnicalFields(copy: copy, tx: tx)
        : const <PresentationField>[];

    final listExpand = includeExpandPayload
        ? _listExpandFields(
            context: context,
            copy: copy,
            tx: tx,
            axes: axes,
            from: from,
            to: to,
            own: own,
            principalLabel: principalLabel,
            totalLabel: amount,
            includeFeesInDebit: includeFeesInDebit,
          )
        : const <PresentationField>[];

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
      listExpandFields: listExpand,
    );
  }

  static List<PresentationField> _buildExpandedFields({
    required BuildContext context,
    required TransactionPresentationCopy copy,
    required Transaction tx,
    required TransactionAxes axes,
    required String from,
    required String to,
    required String own,
    required String principalLabel,
    required String amount,
    required bool includeFeesInDebit,
  }) {
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
          label: tx.isConfirmed
              ? copy.totalDebited
              : context.tr.movementOperationTotal,
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
      final target = tx.onchainConfirmationTarget.clamp(1, 6);
      final confCount = tx.confirmations.clamp(0, target);
      expanded.add(
        PresentationField(
          key: 'confirmations',
          label: copy.confirmations,
          value: '$confCount/$target',
          progressCurrent: confCount,
          progressTarget: target,
        ),
      );
    }

    return expanded;
  }

  /// Complete identifiers for the persistent detail, each with its own meaning.
  /// Compact card fields remain unchanged; internal and network ids are distinct.
  List<PresentationField> detailTechnicalFields(
    BuildContext context,
    Transaction tx, {
    Locale? appLocale,
  }) {
    final copy = TransactionPresentationCopy.of(context);
    final fields = <PresentationField>[];
    void add(String key, String label, String? raw,
        {bool copyable = false, bool technical = false}) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) return;
      fields.add(PresentationField(
          key: key,
          label: label,
          value: value,
          copyable: copyable,
          technical: technical));
    }

    add('onchain-txid', copy.onchainTxid, tx.blockchainTxid,
        copyable: true, technical: true);
    add('payment-hash', copy.paymentHash, tx.paymentHash,
        copyable: true, technical: true);
    if ((tx.blockHeight ?? 0) > 0) {
      add('block', copy.block, '#${tx.blockHeight}', technical: true);
    }
    if (tx.showsOnchainConfirmations) {
      add('block-hash', copy.blockHash, tx.blockHash,
          copyable: true, technical: true);
    }
    add('invoice-id', copy.invoiceId, tx.invoiceId, copyable: true);
    add('lightning-invoice', copy.lightningInvoice, tx.lightningInvoice,
        copyable: true, technical: true);
    add('external-reference', copy.externalRef, tx.externalReference,
        copyable: true);
    add('external-transfer-id', copy.externalTransferId, tx.externalTransferId,
        copyable: true);
    add('external-status', copy.externalStatus, tx.externalTransferStatus);
    add('external-type', copy.externalType, tx.externalTransferType);
    add('wallet-id', copy.yourWallet, tx.walletId, copyable: true);
    add('source-wallet-id', copy.sourceWallet, tx.sourceWalletId,
        copyable: true);
    add('destination-wallet-id', copy.destinationWallet, tx.destinationWalletId,
        copyable: true);
    bool alreadyShown(String key, String? raw) => expandedFields
        .any((field) => field.key == key && field.value.trim() == raw?.trim());
    if (!alreadyShown('from', tx.senderDisplayName)) {
      add('sender-name', context.tr.sendReviewSender, tx.senderDisplayName);
    }
    if (!alreadyShown('to', tx.receiverDisplayName)) {
      add('receiver-name', context.tr.sendReviewDestination,
          tx.receiverDisplayName);
    }
    add('from-address', copy.fromAddress, tx.fromAddress,
        copyable: true, technical: true);
    add('to-address', copy.toAddress, tx.toAddress,
        copyable: true, technical: true);
    add('description', copy.description, tx.description);
    add('internal-id', copy.internalId, tx.id, copyable: true, technical: true);

    final principal = tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis;
    for (final entry in [
      (Currency.usd, tx.displayAmountUsd, copy.frozenUsd),
      (Currency.brl, tx.displayAmountBrl, copy.frozenBrl),
      (Currency.eur, tx.displayAmountEur, copy.frozenEur),
    ]) {
      final recorded = entry.$2;
      if (recorded != null && recorded.isFinite) {
        final value = recorded == 0
            ? MoneyDisplay.format(
                amount: recorded, currency: entry.$1, appLocale: appLocale)
            : MoneyDisplay.formatOperationAmount(
                satoshis: principal,
                currency: entry.$1,
                recordedFiat: recorded,
                appLocale: appLocale);
        add('recorded-${entry.$1.code.toLowerCase()}', entry.$3,
            recorded < 0 ? '-$value' : value);
      }
    }
    return fields;
  }

  static List<PresentationField> _buildTechnicalFields({
    required TransactionPresentationCopy copy,
    required Transaction tx,
  }) {
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
    return technical;
  }

  /// Curated rows for Home/list expand (not the full dossier).
  ///
  /// Matrix by product × rail × direction — see product docs in commit message.
  static List<PresentationField> _listExpandFields({
    required BuildContext context,
    required TransactionPresentationCopy copy,
    required Transaction tx,
    required TransactionAxes axes,
    required String from,
    required String to,
    required String own,
    required String principalLabel,
    required String totalLabel,
    required bool includeFeesInDebit,
  }) {
    final fields = <PresentationField>[];

    void add(
      String key,
      String label,
      String value, {
      bool copyable = false,
    }) {
      final v = value.trim();
      if (v.isEmpty || v == '—') return;
      fields.add(
        PresentationField(
          key: key,
          label: label,
          value: v,
          copyable: copyable,
        ),
      );
    }

    add('when', copy.whenLabel,
        AppDateTime.formatRelativeWithClock(context, tx.timestamp));
    add('status', copy.status, copy.lifecycleLabel(axes.lifecycle));
    add('network', copy.network, copy.railShort(axes.rail));
    add('amount', copy.amountLabel, principalLabel);
    if (!principalLabel.contains('BTC')) {
      add('exact-btc', copy.amountBtc,
          formatSatsAsBtc(tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis));
    }

    final isLink = axes.product == TxProduct.paymentLink;
    final isLightning = axes.rail == TxRail.lightning;
    final incoming = axes.direction == TxDirection.incoming;
    final outgoing = axes.direction == TxDirection.outgoing;

    // Parties — direction-aware, no empty noise.
    if (incoming) {
      add('from', copy.fromPrefix, from);
      add('wallet', copy.destinationWallet, own.isEmpty ? '' : own);
      if (own.isEmpty) add('to', copy.toPrefix, to);
    } else if (outgoing) {
      add('wallet', copy.sourceWallet, own.isEmpty ? '' : own);
      if (own.isEmpty) add('from', copy.fromPrefix, from);
      add('to', copy.toPrefix, to, copyable: looksLikeOnchainAddress(to));
    } else {
      add('from', copy.fromPrefix, from);
      add('to', copy.toPrefix, to, copyable: looksLikeOnchainAddress(to));
    }

    if (isLink) {
      final desc = (tx.description ?? '').trim();
      if (desc.isNotEmpty) {
        add('description', copy.description, desc);
      }
    }

    // Lightning identifiers stay complete for both display and copying.
    if (isLightning || (isLink && tx.isLightningEffective)) {
      final invoice = (tx.lightningInvoice ?? '').trim();
      if (invoice.isNotEmpty) {
        fields.add(
          PresentationField(
            key: 'invoice',
            label: copy.lightningInvoice,
            value: invoice,
            copyable: true,
          ),
        );
      }
      final hash = (tx.paymentHash ?? '').trim();
      if (hash.isNotEmpty) {
        fields.add(
          PresentationField(
            key: 'payment-hash',
            label: copy.paymentHash,
            value: hash,
            copyable: true,
          ),
        );
      }
    }

    // Fees: network (miner/routing) + platform — only when present.
    if (tx.showsNetworkFee) {
      add(
        'network-fee',
        isLightning ? copy.networkFee : copy.networkFee,
        formatSatsAsBtc(tx.feeSatoshis),
      );
    }
    if (tx.showsServiceFee) {
      add('service-fee', copy.serviceFee,
          formatSatsAsBtc(tx.serviceFeeSatoshis));
    }
    if (includeFeesInDebit) {
      add(
          'total',
          tx.isConfirmed
              ? copy.totalDebited
              : context.tr.movementOperationTotal,
          totalLabel);
    }

    // On-chain only: confirmations (+ progress bar metadata) and txid.
    if (tx.showsOnchainConfirmations) {
      final target = tx.onchainConfirmationTarget.clamp(1, 6);
      final conf = tx.confirmations.clamp(0, target);
      final value = '${tx.confirmations.clamp(0, 2147483647)}/$target';
      fields.add(
        PresentationField(
          key: 'confirmations',
          label: copy.confirmations,
          value: value,
          progressCurrent: conf,
          progressTarget: target,
        ),
      );

      final txid = (tx.blockchainTxid ?? '').trim();
      if (txid.isNotEmpty) {
        fields.add(
          PresentationField(
            key: 'txid',
            label: copy.onchainTxid,
            value: txid,
            copyable: true,
          ),
        );
      }
    }

    return fields;
  }

  /// Persistent detail keeps the operation name separate from its status.
  String detailTitle(BuildContext context) {
    final copy = TransactionPresentationCopy.of(context);
    if (axes.product == TxProduct.fee) return copy.fee;
    if (axes.product == TxProduct.swap) return copy.swap;
    // Rail has its own visible label; do not repeat it in the heading.
    final action = axes.direction == TxDirection.incoming
        ? context.tr.typeReceive
        : context.tr.typeSend;
    return axes.product == TxProduct.paymentLink
        ? '$action · ${copy.link}'
        : action;
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

    // Always Envio / Recebimento (never "Saque" / "Depósito" as list title).
    final action = axes.direction == TxDirection.incoming
        ? copy.context.tr.typeReceive
        : copy.context.tr.typeSend;

    if (axes.product == TxProduct.paymentLink) {
      return '$action · ${copy.link}';
    }
    if (axes.product == TxProduct.deposit ||
        axes.product == TxProduct.withdraw) {
      return '$action · ${copy.railShort(axes.rail)}';
    }

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
