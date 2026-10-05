import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/data/entities/withdraw_fee_quote_calculation.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';

/// Inputs for rail-specific fee quotes (display + submit).
class SendQuoteRequest {
  final Wallet wallet;
  final SendDestinationAnalysis destination;
  final double amountBtc;
  final NetworkFeeTier feeTier;
  final FeeEstimate? feeEstimate;
  final bool feeEstimateLoading;
  final Object? feeEstimateError;

  const SendQuoteRequest({
    required this.wallet,
    required this.destination,
    required this.amountBtc,
    required this.feeTier,
    this.feeEstimate,
    this.feeEstimateLoading = false,
    this.feeEstimateError,
  });

  bool get isColdSource =>
      wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable;
}

/// Auth + UI deps for rail execution after the shared auth gate.
class SendExecuteContext {
  final BuildContext context;
  final BuildContext confirmationContext;
  final WidgetRef ref;
  final Wallet wallet;
  final SendDestinationAnalysis destination;
  final double amount;
  final SendFeeQuote feeQuote;
  final String toAddress;
  final String? pendingPaymentLinkId;
  final TransactionAuthResult authResult;
  final Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification;
  final String? Function(String toAddress) resolveRecentDestinationLabel;
  final String Function(String toAddress) resolveRecentDestinationAddress;
  final bool Function() isMounted;

  const SendExecuteContext({
    required this.context,
    required this.confirmationContext,
    required this.ref,
    required this.wallet,
    required this.destination,
    required this.amount,
    required this.feeQuote,
    required this.toAddress,
    required this.pendingPaymentLinkId,
    required this.authResult,
    required this.showSentTransactionNotification,
    required this.resolveRecentDestinationLabel,
    required this.resolveRecentDestinationAddress,
    required this.isMounted,
  });

  bool get isColdSource =>
      wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable;
}

/// Shared quote builders used by send rail handlers.
class SendFeeQuoting {
  const SendFeeQuoting._();

  static SendFeeQuote passthrough({
    required double amountBtc,
    required double platformFeeRate,
    required NetworkFeeTier feeTier,
    Object? error,
  }) {
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      platformFeeBtc: 0,
      networkFeeBtc: 0,
      totalDebitedBtc: amountBtc,
      error: error,
      feeTier: feeTier,
      networkFeeCertainty: NetworkFeeCertainty.known,
    );
  }

  static SendFeeQuote lightning({
    required double amountBtc,
    required double platformFeeRate,
    required NetworkFeeTier feeTier,
  }) {
    final calculation = WithdrawFeeQuoteCalculation.resolve(
      mode: WithdrawFeeMode.senderPays,
      requestedAmountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: 0,
    );
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: calculation.receiverAmountBtc,
      platformFeeRate: calculation.platformFeeRate,
      platformFeeBtc: calculation.platformFeeBtc,
      networkFeeBtc: 0,
      totalDebitedBtc: calculation.totalDebitedBtc,
      feeSource: 'lightning_routing_unknown',
      feeTier: feeTier,
      networkFeeCertainty: NetworkFeeCertainty.unknownUntilPay,
    );
  }

  static SendFeeQuote onchainFromEstimate({
    required double amountBtc,
    required FeeEstimate fee,
    required NetworkFeeTier tier,
  }) {
    final tierPick = FeeTierSelection.fromEstimate(fee, tier: tier);
    final standardNet = fee.estimatedStandardBtc;
    final tierNet = tierPick.networkFeeBtc;
    final delta = tierNet - standardNet;
    final totalDebited = fee.serverPriced
        ? (fee.totalToSend + delta).clamp(0.0, double.infinity)
        : fee.totalToSend;
    final platformFeeRate =
        amountBtc > 0 ? fee.keroseneFeeBtc / amountBtc : 0.0;
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: fee.amountReceived,
      platformFeeRate: platformFeeRate,
      platformFeeBtc: fee.keroseneFeeBtc,
      networkFeeBtc: tierNet,
      networkFeeSats: tierPick.networkFeeSats,
      totalDebitedBtc: totalDebited,
      feeRateSatPerByte: tierPick.feeRateSatPerByte,
      feeRateSatPerVbyte: tierPick.feeRateSatPerVbyte,
      estimatedSettlementSeconds: tierPick.estimatedSettlementSeconds,
      feeTargetBlocks: tierPick.feeTargetBlocks,
      feeSource: fee.feeSource,
      quoteExpiresAt: fee.quoteExpiresAt,
      feeTier: tier,
      networkFeeCertainty: NetworkFeeCertainty.known,
    );
  }

  static SendFeeQuote external({
    required double amountBtc,
    required double platformFeeRate,
    required double networkFeeBtc,
    required NetworkFeeTier feeTier,
    int? networkFeeSats,
    double? feeRateSatPerByte,
    int? feeRateSatPerVbyte,
    int? estimatedSettlementSeconds,
    int? feeTargetBlocks,
    String? feeSource,
    DateTime? quoteExpiresAt,
  }) {
    final calculation = WithdrawFeeQuoteCalculation.resolve(
      mode: WithdrawFeeMode.senderPays,
      requestedAmountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: networkFeeBtc,
    );
    final sats = networkFeeSats != null && networkFeeSats > 0
        ? networkFeeSats
        : (calculation.networkFeeBtc * 100000000).round();
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: calculation.receiverAmountBtc,
      platformFeeRate: calculation.platformFeeRate,
      platformFeeBtc: calculation.platformFeeBtc,
      networkFeeBtc: sats / 100000000.0,
      networkFeeSats: sats,
      totalDebitedBtc: calculation.totalDebitedBtc,
      feeRateSatPerByte: feeRateSatPerByte,
      feeRateSatPerVbyte: feeRateSatPerVbyte ??
          (feeRateSatPerByte != null && feeRateSatPerByte > 0
              ? feeRateSatPerByte.round()
              : null),
      estimatedSettlementSeconds: estimatedSettlementSeconds,
      feeTargetBlocks: feeTargetBlocks,
      feeSource: feeSource,
      quoteExpiresAt: quoteExpiresAt,
      feeTier: feeTier,
      networkFeeCertainty: NetworkFeeCertainty.known,
    );
  }

  static SendFeeQuote fromEstimateAsync({
    required SendQuoteRequest request,
    required double platformFeeRate,
  }) {
    if (request.feeEstimateLoading || request.feeEstimateError != null) {
      return SendFeeQuote(
        requestedAmountBtc: request.amountBtc,
        receiverAmountBtc: request.amountBtc,
        platformFeeRate: platformFeeRate,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: request.amountBtc,
        isLoading: request.feeEstimateLoading,
        error: request.feeEstimateError,
        feeTier: request.feeTier,
        networkFeeCertainty: request.feeEstimateLoading
            ? NetworkFeeCertainty.loading
            : NetworkFeeCertainty.known,
      );
    }

    final fee = request.feeEstimate;
    if (fee == null) {
      return SendFeeQuote(
        requestedAmountBtc: request.amountBtc,
        receiverAmountBtc: request.amountBtc,
        platformFeeRate: platformFeeRate,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: request.amountBtc,
        isLoading: true,
        feeTier: request.feeTier,
        networkFeeCertainty: NetworkFeeCertainty.loading,
      );
    }

    if (fee.serverPriced) {
      return onchainFromEstimate(
        amountBtc: request.amountBtc,
        fee: fee,
        tier: request.feeTier,
      );
    }

    final tierPick = FeeTierSelection.fromEstimate(fee, tier: request.feeTier);
    return external(
      amountBtc: request.amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: tierPick.networkFeeBtc,
      networkFeeSats: tierPick.networkFeeSats,
      feeRateSatPerByte: tierPick.feeRateSatPerByte,
      feeRateSatPerVbyte: tierPick.feeRateSatPerVbyte,
      estimatedSettlementSeconds: tierPick.estimatedSettlementSeconds,
      feeTargetBlocks: tierPick.feeTargetBlocks,
      feeSource: fee.feeSource,
      quoteExpiresAt: fee.quoteExpiresAt,
      feeTier: request.feeTier,
    );
  }
}

/// Kept for type exports used by execute callbacks.
typedef SendSecurityProfileResolver = Future<AccountSecurityProfile> Function(
  Wallet wallet,
);
