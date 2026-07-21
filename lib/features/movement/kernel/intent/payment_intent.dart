import 'package:kerosene/core/utils/bitcoin_network.dart';

/// Parsed destination kind (syntax only — rail resolution is separate).
enum PaymentDestinationKind {
  empty,
  internal,
  paymentLink,
  onchain,
  lightning,
  invalid,
}

/// Execution rail after capabilities + source custody are applied.
enum PaymentRail {
  internal,
  onchain,
  lightning,
  paymentLink,
  coldOnchain,
}

/// Spend source custody class for the selected wallet.
enum SourceCustody {
  internal,
  custodialOnchain,
  watchOnly,
}

/// Hard blockers that fail-closed before auth/submit.
enum PaymentBlockerCode {
  networkMismatch,
  selfPay,
  noCapability,
  quoteExpired,
  amountMissing,
  amountLockedConflict,
  authRequired,
  offline,
  seedMissing,
  invalidDestination,
}

/// Pure parse result from user input (QR, NFC, paste, typed).
class PaymentIntent {
  final PaymentDestinationKind kind;
  final String rawInput;
  final String normalizedValue;
  final String? paymentLinkId;
  final double? amountBtc;
  final String? label;
  final String? message;
  final BitcoinNetworkKind detectedOnchainNetwork;
  final String? invalidReason;

  const PaymentIntent({
    required this.kind,
    required this.rawInput,
    required this.normalizedValue,
    this.paymentLinkId,
    this.amountBtc,
    this.label,
    this.message,
    this.detectedOnchainNetwork = BitcoinNetworkKind.unknown,
    this.invalidReason,
  });

  const PaymentIntent.empty()
      : kind = PaymentDestinationKind.empty,
        rawInput = '',
        normalizedValue = '',
        paymentLinkId = null,
        amountBtc = null,
        label = null,
        message = null,
        detectedOnchainNetwork = BitcoinNetworkKind.unknown,
        invalidReason = null;

  bool get isEmpty => kind == PaymentDestinationKind.empty;
  bool get isInvalid => kind == PaymentDestinationKind.invalid;
  bool get isValid => !isEmpty && !isInvalid;
  bool get isInternal => kind == PaymentDestinationKind.internal;
  bool get isPaymentLink => kind == PaymentDestinationKind.paymentLink;
  bool get isOnchain => kind == PaymentDestinationKind.onchain;
  bool get isLightning => kind == PaymentDestinationKind.lightning;
  bool get isExternal => isOnchain || isLightning;
  bool get hasLockedAmount => amountBtc != null && amountBtc! > 0;

  PaymentIntent copyWith({
    PaymentDestinationKind? kind,
    String? rawInput,
    String? normalizedValue,
    String? paymentLinkId,
    double? amountBtc,
    String? label,
    String? message,
    BitcoinNetworkKind? detectedOnchainNetwork,
    String? invalidReason,
  }) {
    return PaymentIntent(
      kind: kind ?? this.kind,
      rawInput: rawInput ?? this.rawInput,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      paymentLinkId: paymentLinkId ?? this.paymentLinkId,
      amountBtc: amountBtc ?? this.amountBtc,
      label: label ?? this.label,
      message: message ?? this.message,
      detectedOnchainNetwork:
          detectedOnchainNetwork ?? this.detectedOnchainNetwork,
      invalidReason: invalidReason ?? this.invalidReason,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentIntent &&
        other.kind == kind &&
        other.rawInput == rawInput &&
        other.normalizedValue == normalizedValue &&
        other.paymentLinkId == paymentLinkId &&
        other.amountBtc == amountBtc &&
        other.label == label &&
        other.message == message &&
        other.detectedOnchainNetwork == detectedOnchainNetwork &&
        other.invalidReason == invalidReason;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        rawInput,
        normalizedValue,
        paymentLinkId,
        amountBtc,
        label,
        message,
        detectedOnchainNetwork,
        invalidReason,
      );
}

class PaymentBlocker {
  final PaymentBlockerCode code;
  final String message;

  const PaymentBlocker({required this.code, required this.message});
}

class RailOption {
  final PaymentRail rail;
  final String title;
  final String subtitle;
  final bool recommended;

  const RailOption({
    required this.rail,
    required this.title,
    required this.subtitle,
    this.recommended = false,
  });
}

/// Intent after source custody + capabilities + network guards.
class ResolvedPaymentIntent {
  final PaymentIntent intent;
  final SourceCustody source;
  final PaymentRail selectedRail;
  final List<RailOption> alternatives;
  final String? destWalletId;
  final String? destOnchainAddress;
  final String explainWhy;
  final bool amountLocked;
  final List<PaymentBlocker> blockers;

  const ResolvedPaymentIntent({
    required this.intent,
    required this.source,
    required this.selectedRail,
    this.alternatives = const [],
    this.destWalletId,
    this.destOnchainAddress,
    this.explainWhy = '',
    this.amountLocked = false,
    this.blockers = const [],
  });

  bool get canContinue => intent.isValid && blockers.isEmpty;
}
