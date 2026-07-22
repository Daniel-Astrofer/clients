import 'package:kerosene/core/utils/bitcoin_network.dart';

enum SendDestinationType {
  empty,
  internal,
  paymentLink,
  onChain,
  lightning,
  invalid,
}

class SendDestinationAnalysis {
  final SendDestinationType type;
  final String normalizedValue;
  final String? paymentLinkId;
  final double? amountBtc;
  final String? label;
  final String? message;
  final BitcoinNetworkKind detectedOnchainNetwork;

  const SendDestinationAnalysis({
    required this.type,
    required this.normalizedValue,
    this.paymentLinkId,
    this.amountBtc,
    this.label,
    this.message,
    this.detectedOnchainNetwork = BitcoinNetworkKind.unknown,
  });

  bool get isEmpty => type == SendDestinationType.empty;
  bool get isValid => type != SendDestinationType.empty && !isInvalid;
  bool get isInvalid => type == SendDestinationType.invalid;
  bool get isInternal => type == SendDestinationType.internal;
  bool get isPaymentLink => type == SendDestinationType.paymentLink;
  bool get isOnChain => type == SendDestinationType.onChain;
  bool get isLightning => type == SendDestinationType.lightning;
  bool get isExternal => isOnChain || isLightning;
  bool get hasLockedAmount => amountBtc != null && amountBtc! > 0;
}

/// On-chain network fee speed preference (maps to FeeEstimate tiers).
enum NetworkFeeTier { fast, standard, slow }

/// How network fee was obtained for display honesty.
enum NetworkFeeCertainty {
  /// Exact/estimated number from server or client calc.
  known,

  /// Lightning routing not quoted — never invent a constant as "exact".
  unknownUntilPay,

  /// Fee estimate still loading.
  loading,
}

class SendFeeQuote {
  final double requestedAmountBtc;
  final double receiverAmountBtc;
  final double platformFeeRate;
  final double platformFeeBtc;
  final double networkFeeBtc;
  /// Authoritative reserved network fee from backend quote (prefer over BTC).
  final int? networkFeeSats;
  final double totalDebitedBtc;
  final double? feeRateSatPerByte;
  final int? feeRateSatPerVbyte;
  final int? estimatedSettlementSeconds;
  final int? feeTargetBlocks;
  final String? feeSource;
  final DateTime? quoteExpiresAt;
  final bool isLoading;
  final Object? error;
  final NetworkFeeTier feeTier;
  final NetworkFeeCertainty networkFeeCertainty;

  const SendFeeQuote({
    required this.requestedAmountBtc,
    required this.receiverAmountBtc,
    required this.platformFeeRate,
    required this.platformFeeBtc,
    required this.networkFeeBtc,
    this.networkFeeSats,
    required this.totalDebitedBtc,
    this.feeRateSatPerByte,
    this.feeRateSatPerVbyte,
    this.estimatedSettlementSeconds,
    this.feeTargetBlocks,
    this.feeSource,
    this.quoteExpiresAt,
    this.isLoading = false,
    this.error,
    this.feeTier = NetworkFeeTier.standard,
    this.networkFeeCertainty = NetworkFeeCertainty.known,
  });

  bool get hasAmount => requestedAmountBtc > 0;

  /// Integer sats to submit as `networkFeeSats` (backend fee cap).
  int get submitNetworkFeeSats =>
      networkFeeSats != null && networkFeeSats! > 0
          ? networkFeeSats!
          : (networkFeeBtc * 100000000).round();

  /// Integer sat/vB to submit with the reserved fee.
  int? get submitFeeRateSatPerVbyte {
    if (feeRateSatPerVbyte != null && feeRateSatPerVbyte! > 0) {
      return feeRateSatPerVbyte;
    }
    final rate = feeRateSatPerByte;
    if (rate == null || rate <= 0) return null;
    return rate.round();
  }

  bool get isQuoteExpired {
    final expires = quoteExpiresAt;
    if (expires == null) return false;
    return !DateTime.now().toUtc().isBefore(expires.toUtc());
  }

  /// Ready for display / continue when we have a usable quote and it is not stale.
  bool get isReady =>
      hasAmount &&
      !isLoading &&
      error == null &&
      !isQuoteExpired &&
      (networkFeeCertainty != NetworkFeeCertainty.loading);

  /// External on-chain requires a known network fee number.
  bool get isReadyForOnchainSubmit =>
      isReady && networkFeeCertainty == NetworkFeeCertainty.known;

  double get totalFeesBtc => platformFeeBtc + networkFeeBtc;
}
