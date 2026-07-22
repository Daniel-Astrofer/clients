import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_parser.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

/// Legacy bridge: keeps existing call sites working while domain uses [PaymentIntent].
SendDestinationAnalysis currentSendDestinationAnalysis({
  required String? pendingPaymentLinkId,
  required String lockedRecipientAddress,
  required double lockedAmountBtc,
  required String? lockedRecipientLabel,
  required String input,
}) {
  if (pendingPaymentLinkId != null) {
    return SendDestinationAnalysis(
      type: SendDestinationType.paymentLink,
      normalizedValue: lockedRecipientAddress.isNotEmpty
          ? lockedRecipientAddress
          : pendingPaymentLinkId,
      paymentLinkId: pendingPaymentLinkId,
      amountBtc: lockedAmountBtc > 0 ? lockedAmountBtc : null,
      label: lockedRecipientLabel,
    );
  }

  final trimmedInput = input.trim();
  // Cleared field must never stay "valid" via a leftover lock.
  if (trimmedInput.isEmpty) {
    return analyzeSendDestination('');
  }

  final locked = lockedRecipientAddress.trim();
  if (locked.isNotEmpty) {
    final lockedAnalysis = analyzeSendDestination(locked);
    return SendDestinationAnalysis(
      type: lockedAnalysis.type,
      normalizedValue: lockedAnalysis.normalizedValue,
      paymentLinkId: lockedAnalysis.paymentLinkId,
      amountBtc:
          lockedAmountBtc > 0 ? lockedAmountBtc : lockedAnalysis.amountBtc,
      label: lockedRecipientLabel ?? lockedAnalysis.label,
      message: lockedAnalysis.message,
      detectedOnchainNetwork: lockedAnalysis.detectedOnchainNetwork,
    );
  }

  return analyzeSendDestination(input);
}

SendDestinationAnalysis analyzeSendDestination(String raw) {
  return sendDestinationAnalysisFromIntent(
    const PaymentIntentParser().parse(raw),
  );
}

SendDestinationAnalysis sendDestinationAnalysisFromIntent(
    PaymentIntent intent) {
  return SendDestinationAnalysis(
    type: _mapKind(intent.kind),
    normalizedValue: intent.normalizedValue,
    paymentLinkId: intent.paymentLinkId,
    amountBtc: intent.amountBtc,
    label: intent.label,
    message: intent.message,
    detectedOnchainNetwork: intent.detectedOnchainNetwork,
  );
}

SendDestinationType _mapKind(PaymentDestinationKind kind) {
  return switch (kind) {
    PaymentDestinationKind.empty => SendDestinationType.empty,
    PaymentDestinationKind.internal => SendDestinationType.internal,
    PaymentDestinationKind.paymentLink => SendDestinationType.paymentLink,
    PaymentDestinationKind.onchain => SendDestinationType.onChain,
    PaymentDestinationKind.lightning => SendDestinationType.lightning,
    PaymentDestinationKind.invalid => SendDestinationType.invalid,
  };
}

// --- Helpers retained for call sites / tests ---

String stripLightningPrefix(String value) {
  final trimmed = value.trim();
  return trimmed.toLowerCase().startsWith('lightning:')
      ? trimmed.substring(10).trim()
      : trimmed;
}

bool looksLikeLightningRequest(String value) {
  return const PaymentIntentParser().parse(value).isLightning;
}

bool looksLikeLightningAddress(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 254 || trimmed.contains(RegExp(r'\s'))) {
    return false;
  }
  return RegExp(
    r'^[a-zA-Z0-9._%+\-]{1,64}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,63}$',
  ).hasMatch(trimmed);
}

bool looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}

double? extractLightningAmountBtc(String value) {
  final intent = const PaymentIntentParser().parse(value);
  return intent.isLightning ? intent.amountBtc : null;
}
