import 'package:flutter/material.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/app/security/payment_security_guards.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:go_router/go_router.dart';

String sendReviewNote(
  SendDestinationAnalysis destination, {
  required bool isPaymentLink,
  bool coldSource = false,
  BuildContext? context,
}) {
  if (context != null) {
    if (isPaymentLink) return SendMoneyCopy.reviewNotePaymentLink(context);
    if (destination.isLightning) {
      return SendMoneyCopy.reviewNoteLightning(context);
    }
    if (destination.isOnChain) {
      return coldSource
          ? SendMoneyCopy.reviewNoteOnchainCold(context)
          : SendMoneyCopy.reviewNoteOnchain(context);
    }
    return SendMoneyCopy.reviewNoteInternal(context);
  }
  // Fallback for pure unit tests without BuildContext.
  if (isPaymentLink) return 'Pagamento por link interno';
  if (destination.isLightning) return 'Pagamento Lightning';
  if (destination.isOnChain) {
    return coldSource
        ? 'Você assina no aparelho · Kerosene só observa a blockchain'
        : 'Envio on-chain · se o endereço for Kerosene, a entrega vai para a carteira on-chain (custodial/cold) do destinatário com notificação no app';
  }
  return 'Transferência interna Kerosene';
}

Future<InternalTransferReviewArgs<dynamic>?> prepareSendPaymentReview({
  required BuildContext context,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double requestedAmount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required String recipientLabel,
  required double? btcUsd,
  required double? btcEur,
  required double? btcBrl,
  required bool isPaymentLink,
  MovementMoney? money,
  required Future<dynamic> Function(
    BuildContext confirmationContext, {
    required bool firstSendAcknowledgedInReview,
  }) onConfirm,
}) async {
  final displayMoney = money ??
      MovementMoney(
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
        locale: MoneyDisplay.boundAppLocale,
      );
  final coldSource =
      wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable;
  final transferAmountBtc =
      destination.isExternal ? feeQuote.receiverAmountBtc : requestedAmount;
  final totalDebitedBtc =
      destination.isExternal ? feeQuote.totalDebitedBtc : requestedAmount;
  final btcAmountLabel = formatBtcValue(transferAmountBtc);
  const fiatAmountLabel = '';
  final networkLabel = _sendNetworkLabel(
    context,
    destination,
    isPaymentLink: isPaymentLink,
  );
  final partyLabel = _resolveReviewRecipientName(
    recipientLabel: recipientLabel,
    destination: destination,
    toAddress: toAddress,
  );
  final reviewRows = _buildReviewRows(
    context: context,
    wallet: wallet,
    destination: destination,
    requestedAmount: requestedAmount,
    feeQuote: feeQuote,
    toAddress: toAddress,
    recipientLabel: recipientLabel,
    networkLabel: networkLabel,
    fiatAmountLabel: fiatAmountLabel,
    coldSource: coldSource,
    money: displayMoney,
  );

  // First-send lives on the review surface (checkbox), not a post-CTA dialog.
  final requiresFirstSendAck =
      destination.isOnChain && !(await isKnownOnchainSendAddress(toAddress));
  if (!context.mounted) return null;

  final authNextStep = coldSource
      ? SendMoneyCopy.authNextPinAndTotp(context)
      : SendMoneyCopy.authNextDevicePin(context);
  final reviewTitle = SendMoneyCopy.reviewTitle(context);
  final confirmLabel = SendMoneyCopy.authorizeAction(context);
  // Empty → review screen rotates authorizingPhase while confirming.
  const submittingLabel = '';
  final firstSendPreview =
      requiresFirstSendAck ? firstSendAddressPreview(toAddress) : null;

  final showPlatformFee = destination.isExternal &&
      (feeQuote.platformFeeBtc > 0 || feeQuote.isLoading);
  final showMiningFee = destination.isExternal;
  final card = SendPaymentReviewCardData(
    recipientName: partyLabel,
    recipientAddress: compactSendReceiptValue(toAddress, head: 14, tail: 8),
    transferAmountLabel: displayMoney.primary(transferAmountBtc),
    transferFiatLabel: '',
    totalAmountLabel: displayMoney.primary(totalDebitedBtc),
    totalFiatLabel: '',
    networkLabel: networkLabel,
    transactionFeeLabel:
        showPlatformFee ? displayMoney.primary(feeQuote.platformFeeBtc) : null,
    miningFeeLabel: showMiningFee
        ? _networkFeeLabel(context, destination, feeQuote, money: displayMoney)
        : null,
    isInternal: destination.isInternal || destination.isPaymentLink,
    isLightning: destination.isLightning,
    isOnChain: destination.isOnChain,
  );

  return InternalTransferReviewArgs<dynamic>(
    title: reviewTitle,
    amountBtcLabel: btcAmountLabel,
    fiatAmountLabel: _displayFiatLabel(fiatAmountLabel),
    confirmLabel: confirmLabel,
    submittingLabel: submittingLabel,
    destinationLabel: partyLabel,
    networkLabel: networkLabel,
    fromWalletLabel: wallet.name,
    rows: reviewRows,
    card: card,
    requiresFirstSendAck: requiresFirstSendAck,
    firstSendAddressPreview: firstSendPreview,
    firstSendAddress: requiresFirstSendAck ? toAddress : null,
    authNextStepLabel: authNextStep,
    onConfirm: (confirmationContext) async {
      if (requiresFirstSendAck) {
        await markOnchainSendAddressKnown(toAddress);
      }
      if (!confirmationContext.mounted) return null;
      return onConfirm(
        confirmationContext,
        // Review path always owns first-send for on-chain.
        firstSendAcknowledgedInReview: destination.isOnChain,
      );
    },
    receiptBuilder: (result) {
      if (result is! TxStatus) return null;
      return _buildReceiptData(
        context: context,
        status: result,
        wallet: wallet,
        destination: destination,
        requestedAmount: requestedAmount,
        feeQuote: feeQuote,
        toAddress: toAddress,
        recipientLabel: recipientLabel,
        networkLabel: networkLabel,
        money: displayMoney,
      );
    },
  );
}

Future<dynamic> openSendPaymentReview({
  required BuildContext context,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double requestedAmount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required String recipientLabel,
  required double? btcUsd,
  required double? btcEur,
  required double? btcBrl,
  required bool isPaymentLink,
  required Future<dynamic> Function(
    BuildContext confirmationContext, {
    required bool firstSendAcknowledgedInReview,
  }) onConfirm,
}) async {
  final args = await prepareSendPaymentReview(
    context: context,
    wallet: wallet,
    destination: destination,
    requestedAmount: requestedAmount,
    feeQuote: feeQuote,
    toAddress: toAddress,
    recipientLabel: recipientLabel,
    btcUsd: btcUsd,
    btcEur: btcEur,
    btcBrl: btcBrl,
    isPaymentLink: isPaymentLink,
    onConfirm: onConfirm,
  );
  if (!context.mounted || args == null) return null;

  return context.push<dynamic>(
    '/send-money/review',
    extra: args,
  );
}

List<SendPaymentReviewRowData> _buildReviewRows({
  required BuildContext context,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double requestedAmount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required String recipientLabel,
  required String networkLabel,
  required String fiatAmountLabel,
  bool coldSource = false,
  required MovementMoney money,
}) {
  final receiverGets =
      destination.isExternal ? feeQuote.receiverAmountBtc : requestedAmount;
  final youPay =
      destination.isExternal ? feeQuote.totalDebitedBtc : requestedAmount;

  // Primary: amounts / ETA / total.
  // Detail (collapsible): destination, network, wallet, signature.
  final rows = <SendPaymentReviewRowData>[
    SendPaymentReviewRowData(
      label: context.tr.sendReviewDestination,
      value: _displayParty(recipientLabel, toAddress),
      technical: recipientLabel.trim().isEmpty,
      detail: true,
    ),
    SendPaymentReviewRowData(
      label: SendMoneyCopy.networkRowLabel(context),
      value: networkLabel,
      detail: true,
    ),
    SendPaymentReviewRowData(
      label: context.tr.sendReviewWallet,
      value: wallet.name,
      detail: true,
    ),
    if (coldSource)
      SendPaymentReviewRowData(
        label: SendMoneyCopy.signatureRowLabel(context),
        value: SendMoneyCopy.signatureOnDevice(context),
        detail: true,
      ),
    SendPaymentReviewRowData(
      label: context.tr.sendReviewRecipientGets,
      value: money.primary(receiverGets),
      numeric: true,
    ),
    if (destination.isExternal) ...[
      SendPaymentReviewRowData(
        label: context.tr.sendReviewNetworkFee,
        value: _networkFeeLabel(context, destination, feeQuote, money: money),
        numeric: true,
      ),
      if (feeQuote.platformFeeBtc > 0 || feeQuote.isLoading)
        SendPaymentReviewRowData(
          label: context.tr.sendReviewKeroseneFee,
          value: money.primary(feeQuote.platformFeeBtc),
          numeric: true,
        ),
    ],
  ];

  rows.addAll([
    SendPaymentReviewRowData(
      label: context.tr.sendReviewEstimatedTime,
      value: estimatedSendTime(
        destination,
        estimatedSeconds: feeQuote.estimatedSettlementSeconds,
        testnetLike: expectedBitcoinNetwork != BitcoinNetworkKind.mainnet &&
            expectedBitcoinNetwork != BitcoinNetworkKind.unknown,
      ),
    ),
    // Bank-style total last — always visible so user sees full debit.
    SendPaymentReviewRowData(
      label: context.tr.sendReviewYouPay,
      value: money.primary(youPay),
      numeric: true,
      emphasize: true,
    ),
  ]);

  return rows;
}

SendPaymentReceiptData _buildReceiptData({
  required BuildContext context,
  required TxStatus status,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double requestedAmount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required String recipientLabel,
  required String networkLabel,
  required MovementMoney money,
}) {
  final occurredAt = status.occurredAt;
  final amountFallback =
      destination.isExternal ? feeQuote.receiverAmountBtc : requestedAmount;
  final amountLabel = money.primary(
    status.hasAmount || status.amountReceived > 0
        ? status.amountReceived
        : amountFallback,
  );
  final sender = _firstNotEmpty(status.sender, wallet.address, wallet.name);
  final receiver = _firstNotEmpty(status.receiver, toAddress, recipientLabel);
  final networkFee = status.hasNetworkFee || status.networkFeeBtc > 0
      ? status.networkFeeBtc
      : feeQuote.networkFeeBtc;
  final platformFee = status.hasPlatformFee || status.platformFeeBtc > 0
      ? status.platformFeeBtc
      : feeQuote.platformFeeBtc;
  final totalDebited = status.hasTotalDebited || status.totalDebitedBtc > 0
      ? status.totalDebitedBtc
      : feeQuote.totalDebitedBtc;

  final rows = <SendPaymentReceiptRowData>[
    SendPaymentReceiptRowData(
      label: context.tr.sendReviewSender,
      value: compactSendReceiptValue(sender, head: 14, tail: 8),
      technical: sender.length > 24,
    ),
    SendPaymentReceiptRowData(
      label: context.tr.sendReviewWallet,
      value: wallet.name,
    ),
    SendPaymentReceiptRowData(
      label: SendMoneyCopy.networkRowLabel(context),
      value: networkLabel,
    ),
    SendPaymentReceiptRowData(
      label: context.tr.sendReviewDestination,
      value: compactSendReceiptValue(receiver, head: 14, tail: 8),
      technical: receiver.length > 24,
    ),
  ];

  if (networkFee > 0 || (destination.isExternal && status.hasNetworkFee)) {
    rows.add(
      SendPaymentReceiptRowData(
        label: context.tr.sendReviewNetworkFee,
        value: money.primary(networkFee),
        secondaryValue: money.secondary(networkFee),
        numeric: true,
        kind: SendPaymentReceiptRowKind.networkFee,
      ),
    );
  }

  if (platformFee > 0) {
    rows.add(
      SendPaymentReceiptRowData(
        label: context.tr.sendReviewKeroseneFee,
        value: money.primary(platformFee),
        secondaryValue: money.secondary(platformFee),
        numeric: true,
        kind: SendPaymentReceiptRowKind.platformFee,
      ),
    );
  }

  if (status.hasTotalDebited || networkFee > 0 || platformFee > 0) {
    rows.add(
      SendPaymentReceiptRowData(
        label: status.isConfirmed
            ? context.tr.sendReviewTotalDebited
            : context.tr.receiptExpectedTotal,
        value: money.primary(totalDebited),
        secondaryValue: money.secondary(totalDebited),
        numeric: true,
        kind: SendPaymentReceiptRowKind.total,
      ),
    );
  }

  if (status.status.trim().isNotEmpty) {
    rows.add(
      SendPaymentReceiptRowData(
        label: context.tr.sendReviewStatus,
        value: _statusLabel(context, status.status),
        kind: SendPaymentReceiptRowKind.status,
      ),
    );
  }

  if (status.txid.trim().isNotEmpty) {
    rows.add(
      SendPaymentReceiptRowData(
        label: context.tr.sendReviewTxId,
        value: compactSendReceiptValue(status.txid, head: 10, tail: 8),
        numeric: true,
        technical: true,
        kind: SendPaymentReceiptRowKind.networkReference,
      ),
    );
  }

  final title = status.isConfirmed
      ? SendMoneyCopy.receiptTitleConfirmed(context)
      : SendMoneyCopy.receiptTitleSubmitted(context);
  final subtitle = status.isConfirmed
      ? SendMoneyCopy.receiptSubtitleConfirmed(context)
      : SendMoneyCopy.receiptSubtitlePending(context);

  return SendPaymentReceiptData(
    money: money,
    title: title,
    subtitle: subtitle,
    confirmed: status.isConfirmed,
    transactionId: status.transactionId,
    amountLabel: amountLabel,
    secondaryAmountLabel: money.secondary(
        status.hasAmount || status.amountReceived > 0
            ? status.amountReceived
            : amountFallback),
    occurredAt: occurredAt,
    updatedAt: status.updatedAt,
    rows: rows,
    shareText: _receiptShareText(
      context: context,
      title: title,
      amountLabel: amountLabel,
      occurredAt: occurredAt,
      rows: rows,
    ),
  );
}

String _sendNetworkLabel(
  BuildContext context,
  SendDestinationAnalysis destination, {
  required bool isPaymentLink,
}) {
  return SendMoneyCopy.networkLabel(
    context,
    isPaymentLink: isPaymentLink || destination.isPaymentLink,
    isLightning: destination.isLightning,
    isOnChain: destination.isOnChain,
  );
}

String _networkFeeLabel(
  BuildContext context,
  SendDestinationAnalysis destination,
  SendFeeQuote feeQuote, {
  MovementMoney? money,
}) {
  if (!destination.isExternal) return SendMoneyCopy.feeFree(context);
  if (feeQuote.networkFeeCertainty == NetworkFeeCertainty.unknownUntilPay) {
    return SendMoneyCopy.feeEstimatedAtPayment(context);
  }
  if (feeQuote.networkFeeCertainty == NetworkFeeCertainty.loading) {
    return SendMoneyCopy.feeCalculating(context);
  }
  final fee = money?.primary(feeQuote.networkFeeBtc) ??
      '${formatBtcValue(feeQuote.networkFeeBtc)} BTC';
  return fee;
}

String _resolveReviewRecipientName({
  required String recipientLabel,
  required SendDestinationAnalysis destination,
  required String toAddress,
}) {
  for (final raw in [recipientLabel, destination.label ?? '']) {
    final label = raw.trim();
    if (label.isEmpty || label == toAddress) continue;
    return label;
  }
  return _displayParty(recipientLabel, toAddress);
}

String _displayFiatLabel(String value) => value.trim();

String _displayParty(String label, String value) {
  final cleanLabel = label.trim();
  if (cleanLabel.isNotEmpty) return cleanLabel;
  return compactSendReceiptValue(value, head: 14, tail: 8);
}

String _firstNotEmpty(String first, String second, String third) {
  for (final value in [first, second, third]) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return 'Kerosene';
}

String _statusLabel(BuildContext context, String value) {
  switch (value.trim().toUpperCase()) {
    case 'SETTLED':
    case 'COMPLETED':
    case 'CONFIRMED':
    case 'PAID':
      return context.tr.txListConfirmed;
    case 'REQUIRES_RECONCILIATION':
      return context.tr.txListNeedsReview;
    case 'CANCELLED':
    case 'CANCELED':
      return context.tr.txListCancelled;
    case 'FAILED':
    case 'REJECTED':
      return context.tr.txListFailed;
    default:
      return context.tr.txListPending;
  }
}

String _receiptShareText({
  required BuildContext context,
  required String title,
  required String amountLabel,
  required DateTime? occurredAt,
  required List<SendPaymentReceiptRowData> rows,
}) {
  final lines = <String>[
    title,
    '${SendMoneyCopy.receiptShareAmount(context)}: $amountLabel',
    if (occurredAt != null)
      '${SendMoneyCopy.receiptDateLabel(context)}: ${_shareDate(occurredAt)}',
    for (final row in rows)
      '${row.label}: ${row.value}${row.secondaryValue.isEmpty ? '' : ' (${row.secondaryValue})'}',
  ];
  return lines.join('\n');
}

String _shareDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
