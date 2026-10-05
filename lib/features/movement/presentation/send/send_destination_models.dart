import 'package:kerosene/core/utils/bitcoin_network.dart';

/// Classification produced when parsing a destination entered by the sender.
enum SendDestinationType {
  /// No non-whitespace destination was provided.
  empty,

  /// A valid internal recipient identifier.
  internal,

  /// A valid Kerosene payment-link identifier.
  paymentLink,

  /// A valid Bitcoin on-chain address.
  onChain,

  /// A valid Lightning invoice or address.
  lightning,

  /// Input that cannot be used as a supported destination.
  invalid,
}

/// Normalized interpretation of a user-entered payment destination.
///
/// Parsing keeps invalid/empty input distinct from valid internal transfers,
/// payment links, on-chain addresses, and Lightning invoices so the send flow
/// can select the right validation and fee path.
class SendDestinationAnalysis {
  /// Category assigned to the parsed destination.
  final SendDestinationType type;

  /// Canonical value to use for subsequent lookup or payment creation.
  final String normalizedValue;

  /// Identifier extracted from a payment link, if the input is one.
  final String? paymentLinkId;

  /// Fixed amount embedded in the destination, when present, in BTC.
  final double? amountBtc;

  /// Optional recipient label carried by a URI or payment link.
  final String? label;

  /// Optional message carried by the destination.
  final String? message;

  /// Bitcoin network inferred from an on-chain address, if recognized.
  final BitcoinNetworkKind detectedOnchainNetwork;

  /// Creates the parser result with an unknown network as the default.
  const SendDestinationAnalysis({
    required this.type,
    required this.normalizedValue,
    this.paymentLinkId,
    this.amountBtc,
    this.label,
    this.message,
    this.detectedOnchainNetwork = BitcoinNetworkKind.unknown,
  });

  /// Whether parsing produced no destination value.
  bool get isEmpty => type == SendDestinationType.empty;

  /// Whether the destination is present and was not rejected as invalid.
  bool get isValid => type != SendDestinationType.empty && !isInvalid;

  /// Whether parsing recognized a malformed or unsupported destination.
  bool get isInvalid => type == SendDestinationType.invalid;

  /// Whether the destination resolves to an internal Kerosene recipient.
  bool get isInternal => type == SendDestinationType.internal;

  /// Whether the destination resolves to a Kerosene payment link.
  bool get isPaymentLink => type == SendDestinationType.paymentLink;

  /// Whether the destination is a Bitcoin on-chain address.
  bool get isOnChain => type == SendDestinationType.onChain;

  /// Whether the destination is a Lightning invoice or address.
  bool get isLightning => type == SendDestinationType.lightning;

  /// Whether the payment leaves the internal transfer domain.
  bool get isExternal => isOnChain || isLightning;

  /// Whether an embedded positive amount must be treated as fixed.
  bool get hasLockedAmount => amountBtc != null && amountBtc! > 0;
}

/// On-chain network fee speed preference (maps to FeeEstimate tiers).
enum NetworkFeeTier {
  /// Prefer a quicker confirmation target, usually at a higher fee.
  fast,

  /// Use the default balance of confirmation time and fee.
  standard,

  /// Prefer a lower fee when a longer confirmation time is acceptable.
  slow,
}

/// How network fee was obtained for display honesty.
enum NetworkFeeCertainty {
  /// Exact/estimated number from server or client calc.
  known,

  /// Lightning routing not quoted — never invent a constant as "exact".
  unknownUntilPay,

  /// Fee estimate still loading.
  loading,
}

/// Fee, payout, and expiry information used to review an outgoing payment.
///
/// BTC amounts are retained for user-facing calculations; integer satoshi and
/// sat/vbyte values represent backend submission caps when supplied.
class SendFeeQuote {
  /// Amount requested by the sender before fee deduction, in BTC.
  final double requestedAmountBtc;

  /// Amount expected to reach the recipient, in BTC.
  final double receiverAmountBtc;

  /// Platform fee rate applied to the quote.
  final double platformFeeRate;

  /// Platform fee amount in BTC.
  final double platformFeeBtc;

  /// Estimated network fee in BTC.
  final double networkFeeBtc;

  /// Authoritative reserved network fee from backend quote (prefer over BTC).
  /// Authoritative backend fee cap in satoshis, when returned by the quote API.
  final int? networkFeeSats;

  /// Total amount to debit from the sender, in BTC.
  final double totalDebitedBtc;

  /// Fee rate estimate in satoshis per byte, if the source provides it.
  final double? feeRateSatPerByte;

  /// Preferred fee rate in satoshis per virtual byte for submission.
  final int? feeRateSatPerVbyte;

  /// Estimated settlement duration in seconds, if known.
  final int? estimatedSettlementSeconds;

  /// Confirmation target represented by the fee estimate, if known.
  final int? feeTargetBlocks;

  /// Name of the component that produced the fee estimate.
  final String? feeSource;

  /// UTC instant after which the quoted values must not be used.
  final DateTime? quoteExpiresAt;

  /// Whether the fee request is still being resolved.
  final bool isLoading;

  /// Failure associated with quote loading, if any.
  final Object? error;

  /// User-selected network fee speed tier.
  final NetworkFeeTier feeTier;

  /// Whether the network fee is known, pending, or unavailable until payment.
  final NetworkFeeCertainty networkFeeCertainty;

  /// Creates a quote snapshot; optional rate and timing fields may be absent.
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

  /// Whether the requested amount is positive.
  bool get hasAmount => requestedAmountBtc > 0;

  /// Integer sats to submit as `networkFeeSats` (backend fee cap).
  int get submitNetworkFeeSats => networkFeeSats != null && networkFeeSats! > 0
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

  /// Whether the quote expiry instant has passed according to the UTC clock.
  bool get isQuoteExpired {
    final expires = quoteExpiresAt;
    if (expires == null) return false;
    return !DateTime.now().toUtc().isBefore(expires.toUtc());
  }

  /// Ready for display / continue when we have a usable quote and it is not stale.
  /// Whether all common prerequisites for showing/continuing are satisfied.
  bool get isReady =>
      hasAmount &&
      !isLoading &&
      error == null &&
      !isQuoteExpired &&
      (networkFeeCertainty != NetworkFeeCertainty.loading);

  /// External on-chain requires a known network fee number.
  bool get isReadyForOnchainSubmit =>
      isReady && networkFeeCertainty == NetworkFeeCertainty.known;

  /// Sum of platform and network fee amounts in BTC.
  double get totalFeesBtc => platformFeeBtc + networkFeeBtc;
}
