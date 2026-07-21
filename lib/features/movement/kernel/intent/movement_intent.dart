import 'package:kerosene/core/utils/bitcoin_network.dart';

enum MovementIntentKind {
  empty,
  internal,
  paymentLink,
  onchain,
  lightning,
  invalid,
  opaque,
}

class MovementIntent {
  final MovementIntentKind kind;
  final String rawInput;
  final String normalizedValue;
  final String? paymentLinkId;
  final double? amountBtc;
  final String? label;
  final String? message;
  final BitcoinNetworkKind detectedOnchainNetwork;
  final Map<String, dynamic> hints;
  final String? invalidReason;

  const MovementIntent({
    required this.kind,
    required this.rawInput,
    required this.normalizedValue,
    this.paymentLinkId,
    this.amountBtc,
    this.label,
    this.message,
    this.detectedOnchainNetwork = BitcoinNetworkKind.unknown,
    this.hints = const {},
    this.invalidReason,
  });

  const MovementIntent.empty()
      : kind = MovementIntentKind.empty,
        rawInput = '',
        normalizedValue = '',
        paymentLinkId = null,
        amountBtc = null,
        label = null,
        message = null,
        detectedOnchainNetwork = BitcoinNetworkKind.unknown,
        hints = const {},
        invalidReason = null;

  factory MovementIntent.opaque({
    required String raw,
    Map<String, dynamic> hints = const {},
  }) {
    return MovementIntent(
      kind: MovementIntentKind.opaque,
      rawInput: raw,
      normalizedValue: raw,
      hints: hints,
    );
  }

  bool get isEmpty => kind == MovementIntentKind.empty;
  bool get isInvalid => kind == MovementIntentKind.invalid;
  bool get isValid => !isEmpty && !isInvalid;
  bool get isInternal => kind == MovementIntentKind.internal;
  bool get isPaymentLink => kind == MovementIntentKind.paymentLink;
  bool get isOnchain => kind == MovementIntentKind.onchain;
  bool get isLightning => kind == MovementIntentKind.lightning;
  bool get isExternal => isOnchain || isLightning;
  bool get hasLockedAmount => amountBtc != null && amountBtc! > 0;

  MovementIntent copyWith({
    MovementIntentKind? kind,
    String? rawInput,
    String? normalizedValue,
    String? paymentLinkId,
    double? amountBtc,
    String? label,
    String? message,
    BitcoinNetworkKind? detectedOnchainNetwork,
    Map<String, dynamic>? hints,
    String? invalidReason,
  }) {
    return MovementIntent(
      kind: kind ?? this.kind,
      rawInput: rawInput ?? this.rawInput,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      paymentLinkId: paymentLinkId ?? this.paymentLinkId,
      amountBtc: amountBtc ?? this.amountBtc,
      label: label ?? this.label,
      message: message ?? this.message,
      detectedOnchainNetwork:
          detectedOnchainNetwork ?? this.detectedOnchainNetwork,
      hints: hints ?? this.hints,
      invalidReason: invalidReason ?? this.invalidReason,
    );
  }
}
