import 'package:kerosene/features/movement/kernel/intent/movement_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

/// Bridges the send-domain [PaymentIntent] model and the kernel [MovementIntent].
///
/// Phase-1 left both types in place; send shell talks to handlers via
/// [MovementIntent] while parse/resolve still use [PaymentIntent].
MovementIntent movementIntentFromPayment(PaymentIntent intent) {
  return MovementIntent(
    kind: _kindFromPayment(intent.kind),
    rawInput: intent.rawInput,
    normalizedValue: intent.normalizedValue,
    paymentLinkId: intent.paymentLinkId,
    amountBtc: intent.amountBtc,
    label: intent.label,
    message: intent.message,
    detectedOnchainNetwork: intent.detectedOnchainNetwork,
    invalidReason: intent.invalidReason,
  );
}

PaymentIntent paymentIntentFromMovement(MovementIntent intent) {
  return PaymentIntent(
    kind: _kindToPayment(intent.kind),
    rawInput: intent.rawInput,
    normalizedValue: intent.normalizedValue,
    paymentLinkId: intent.paymentLinkId,
    amountBtc: intent.amountBtc,
    label: intent.label,
    message: intent.message,
    detectedOnchainNetwork: intent.detectedOnchainNetwork,
    invalidReason: intent.invalidReason,
  );
}

MovementIntent movementIntentFromDestination(SendDestinationAnalysis destination) {
  return MovementIntent(
    kind: _kindFromDestination(destination.type),
    rawInput: destination.normalizedValue,
    normalizedValue: destination.normalizedValue,
    paymentLinkId: destination.paymentLinkId,
    amountBtc: destination.amountBtc,
    label: destination.label,
    message: destination.message,
    detectedOnchainNetwork: destination.detectedOnchainNetwork,
  );
}

PaymentIntent paymentIntentFromDestination(SendDestinationAnalysis destination) {
  return paymentIntentFromMovement(movementIntentFromDestination(destination));
}

MovementIntentKind _kindFromPayment(PaymentDestinationKind kind) {
  return switch (kind) {
    PaymentDestinationKind.empty => MovementIntentKind.empty,
    PaymentDestinationKind.internal => MovementIntentKind.internal,
    PaymentDestinationKind.paymentLink => MovementIntentKind.paymentLink,
    PaymentDestinationKind.onchain => MovementIntentKind.onchain,
    PaymentDestinationKind.lightning => MovementIntentKind.lightning,
    PaymentDestinationKind.invalid => MovementIntentKind.invalid,
  };
}

PaymentDestinationKind _kindToPayment(MovementIntentKind kind) {
  return switch (kind) {
    MovementIntentKind.empty => PaymentDestinationKind.empty,
    MovementIntentKind.internal => PaymentDestinationKind.internal,
    MovementIntentKind.paymentLink => PaymentDestinationKind.paymentLink,
    MovementIntentKind.onchain => PaymentDestinationKind.onchain,
    MovementIntentKind.lightning => PaymentDestinationKind.lightning,
    MovementIntentKind.invalid => PaymentDestinationKind.invalid,
    MovementIntentKind.opaque => PaymentDestinationKind.internal,
  };
}

MovementIntentKind _kindFromDestination(SendDestinationType type) {
  return switch (type) {
    SendDestinationType.empty => MovementIntentKind.empty,
    SendDestinationType.internal => MovementIntentKind.internal,
    SendDestinationType.paymentLink => MovementIntentKind.paymentLink,
    SendDestinationType.onChain => MovementIntentKind.onchain,
    SendDestinationType.lightning => MovementIntentKind.lightning,
    SendDestinationType.invalid => MovementIntentKind.invalid,
  };
}
