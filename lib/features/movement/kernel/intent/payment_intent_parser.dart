import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';

/// Canonical payment destination parser for home, send, QR, NFC, and deep links.
///
/// Pure / side-effect free. Rail selection and network API live in the resolver.
class PaymentIntentParser {
  const PaymentIntentParser();

  static const PaymentIntentParser instance = PaymentIntentParser();

  PaymentIntent parse(String raw) {
    try {
      return _parseUnsafe(raw);
    } catch (_) {
      // Clipboard / NFC / QR can yield malformed UTF-8 or URI edge cases.
      return PaymentIntent(
        kind: PaymentDestinationKind.invalid,
        rawInput: raw,
        normalizedValue: raw.trim(),
        invalidReason: 'parse_exception',
      );
    }
  }

  PaymentIntent _parseUnsafe(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const PaymentIntent.empty();
    }

    final linkId = QrPaymentParser.extractPaymentLinkId(trimmed);
    if (linkId != null) {
      return PaymentIntent(
        kind: PaymentDestinationKind.paymentLink,
        rawInput: trimmed,
        normalizedValue: linkId,
        paymentLinkId: linkId,
      );
    }

    final parsed = QrPaymentParser.decode(trimmed);
    final preferred = parsed?.preferredDestination.trim().isNotEmpty == true
        ? parsed!.preferredDestination.trim()
        : _stripLightningPrefix(trimmed);

    if (_looksLikeLightningRequest(preferred)) {
      return PaymentIntent(
        kind: PaymentDestinationKind.lightning,
        rawInput: trimmed,
        normalizedValue: preferred,
        amountBtc: parsed?.amountBtc ?? _extractLightningAmountBtc(preferred),
        label: parsed?.label,
        message: parsed?.message,
      );
    }

    // On-chain: prefer decoded address; fall back to preferred destination.
    final onchainCandidate = () {
      final fromParsed = parsed?.address.trim() ?? '';
      if (fromParsed.isNotEmpty && looksLikeBitcoinAddress(fromParsed)) {
        return fromParsed;
      }
      if (looksLikeBitcoinAddress(preferred)) {
        return preferred;
      }
      return '';
    }();

    if (onchainCandidate.isNotEmpty) {
      return PaymentIntent(
        kind: PaymentDestinationKind.onchain,
        rawInput: trimmed,
        normalizedValue: onchainCandidate,
        amountBtc: parsed?.amountBtc,
        label: parsed?.label,
        message: parsed?.message,
        detectedOnchainNetwork: inferBitcoinNetworkFromAddress(onchainCandidate),
      );
    }

    // kerosene:pay?address=... internal-style URI with embedded address/user.
    if (trimmed.toLowerCase().startsWith('kerosene:pay') &&
        parsed != null &&
        parsed.address.trim().isNotEmpty) {
      final address = parsed.address.trim();
      final internal = normalizeInternalDestination(address);
      if (isValidInternalDestination(internal) ||
          looksLikeBitcoinAddress(address)) {
        final isBtc = looksLikeBitcoinAddress(address);
        return PaymentIntent(
          kind: isBtc
              ? PaymentDestinationKind.onchain
              : PaymentDestinationKind.internal,
          rawInput: trimmed,
          normalizedValue: isBtc ? address : internal,
          amountBtc: parsed.amountBtc,
          label: parsed.label,
          message: parsed.message,
          detectedOnchainNetwork:
              isBtc ? inferBitcoinNetworkFromAddress(address) : BitcoinNetworkKind.unknown,
        );
      }
    }

    final internalCandidate = normalizeInternalDestination(preferred);
    if (isValidInternalDestination(internalCandidate)) {
      return PaymentIntent(
        kind: PaymentDestinationKind.internal,
        rawInput: trimmed,
        normalizedValue: internalCandidate,
        amountBtc: parsed?.amountBtc,
        label: parsed?.label,
        message: parsed?.message,
      );
    }

    // Whitespace or unknown scheme → invalid (never silent payment-link).
    if (RegExp(r'\s').hasMatch(trimmed)) {
      return PaymentIntent(
        kind: PaymentDestinationKind.invalid,
        rawInput: trimmed,
        normalizedValue: preferred,
        invalidReason: 'whitespace',
      );
    }

    return PaymentIntent(
      kind: PaymentDestinationKind.invalid,
      rawInput: trimmed,
      normalizedValue: preferred,
      invalidReason: 'unrecognized_destination',
    );
  }

  /// Convenience for locked / pre-resolved payment link flows.
  PaymentIntent paymentLink({
    required String linkId,
    String? rawInput,
    double? amountBtc,
    String? label,
  }) {
    final id = linkId.trim();
    return PaymentIntent(
      kind: PaymentDestinationKind.paymentLink,
      rawInput: rawInput ?? 'kerosene:link:$id',
      normalizedValue: id,
      paymentLinkId: id,
      amountBtc: amountBtc,
      label: label,
    );
  }
}

String _stripLightningPrefix(String value) {
  final trimmed = value.trim();
  return trimmed.toLowerCase().startsWith('lightning:')
      ? trimmed.substring(10).trim()
      : trimmed;
}

bool _looksLikeLightningRequest(String value) {
  final trimmed = _stripLightningPrefix(value);
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  // BOLT11 (incl. amountless), LNURL1, Lightning Address, keysend pubkey.
  return RegExp(r'^(lnbc|lntb|lnbcrt|lnsb|lntbs)[0-9a-z]+$').hasMatch(lower) ||
      RegExp(r'^lnurl1[0-9a-z]+$').hasMatch(lower) ||
      RegExp(r'^[0-9a-f]{66}$').hasMatch(lower) ||
      _looksLikeLightningAddress(trimmed);
}

bool _looksLikeLightningAddress(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 254 || trimmed.contains(RegExp(r'\s'))) {
    return false;
  }
  return RegExp(
    r'^[a-zA-Z0-9._%+\-]{1,64}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,63}$',
  ).hasMatch(trimmed);
}

double? _extractLightningAmountBtc(String value) {
  final withoutPrefix = _stripLightningPrefix(value);
  final match = RegExp(
    r'^ln(?:bc|tb|bcrt)(\d+)([munp]?)1',
  ).firstMatch(withoutPrefix.toLowerCase());
  if (match == null) return null;
  final amount = double.tryParse(match.group(1) ?? '');
  if (amount == null || amount <= 0) return null;

  final multiplier = switch (match.group(2)) {
    'm' => 0.001,
    'u' => 0.000001,
    'n' => 0.000000001,
    'p' => 0.000000000001,
    _ => 1.0,
  };
  return amount * multiplier;
}
