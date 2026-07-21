import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kFirstSendAddressesPrefsKey = 'payment.first_send_addresses_v1';

/// App default network for local/test deployments (testnet4 addresses are tb1…).
/// Mainnet builds can override via [expectedBitcoinNetworkOverride].
BitcoinNetworkKind expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;

BitcoinNetworkKind get expectedBitcoinNetwork => expectedBitcoinNetworkOverride;

/// Returns a human error if [address] is incompatible with the app network.
String? networkMismatchMessage(String address, {BuildContext? context}) {
  final expected = expectedBitcoinNetwork;
  if (expected == BitcoinNetworkKind.unknown) return null;
  if (!looksLikeBitcoinAddress(address)) return null;
  if (isBitcoinAddressCompatibleWithNetwork(address, expected)) return null;
  final detected = inferBitcoinNetworkFromAddress(address);
  final detectedLabel = bitcoinNetworkDisplayName(detected);
  final expectedLabel = bitcoinNetworkDisplayName(expected);
  if (context != null) {
    // Lazy import path: callers pass context for en/es/pt.
    return _networkMismatchLocalized(
      context,
      detected: detectedLabel,
      expected: expectedLabel,
    );
  }
  return 'Rede do endereço ($detectedLabel) '
      'não confere com a rede do app ($expectedLabel).';
}

String _networkMismatchLocalized(
  BuildContext context, {
  required String detected,
  required String expected,
}) {
  final lang = Localizations.localeOf(context).languageCode;
  return switch (lang) {
    'en' =>
      'Address network ($detected) does not match the app network ($expected).',
    'es' =>
      'La red de la dirección ($detected) no coincide con la del app ($expected).',
    _ =>
      'Rede do endereço ($detected) não confere com a rede do app ($expected).',
  };
}

String normalizeFirstSendAddressKey(String address) {
  return normalizeBitcoinAddressForDisplay(address.trim()).toLowerCase();
}

String firstSendAddressPreview(String address) {
  final trimmed = address.trim();
  if (trimmed.length <= 14) return trimmed;
  return '${trimmed.substring(0, 8)}…${trimmed.substring(trimmed.length - 6)}';
}

/// Whether this on-chain address has already been confirmed once on-device.
Future<bool> isKnownOnchainSendAddress(
  String address, {
  SharedPreferences? prefs,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty || !looksLikeBitcoinAddress(trimmed)) {
    return true;
  }
  final storage = prefs ?? await SharedPreferences.getInstance();
  final known = storage.getStringList(kFirstSendAddressesPrefsKey) ?? const [];
  final key = normalizeFirstSendAddressKey(trimmed);
  return known.any((e) => e.toLowerCase() == key);
}

/// Persist a first-send acknowledgement (address poisoning mitigation).
Future<void> markOnchainSendAddressKnown(
  String address, {
  SharedPreferences? prefs,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty || !looksLikeBitcoinAddress(trimmed)) {
    return;
  }
  final storage = prefs ?? await SharedPreferences.getInstance();
  final known = storage.getStringList(kFirstSendAddressesPrefsKey) ?? const [];
  final key = normalizeFirstSendAddressKey(trimmed);
  if (known.any((e) => e.toLowerCase() == key)) {
    return;
  }
  final next = {...known, key}.toList(growable: false);
  final capped = next.length > 200 ? next.sublist(next.length - 200) : next;
  await storage.setStringList(kFirstSendAddressesPrefsKey, capped);
}

/// Confirms first-time on-chain destinations (dialog fallback for non-review paths).
///
/// Prefer inline review acknowledgement when available; this remains for cold /
/// legacy call sites.
Future<bool> confirmFirstTimeOnchainAddress({
  required BuildContext context,
  required String address,
  SharedPreferences? prefs,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty || !looksLikeBitcoinAddress(trimmed)) {
    return true;
  }

  if (await isKnownOnchainSendAddress(trimmed, prefs: prefs)) {
    return true;
  }

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final head = firstSendAddressPreview(trimmed);
          return AlertDialog(
            backgroundColor: KeroseneBrandTokens.surface,
            title: Text(
              _title(dialogContext),
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              _body(dialogContext, head),
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  _cancel(dialogContext),
                  style: AppTypography.inter(
                    color: KeroseneBrandTokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  _confirm(dialogContext),
                  style: AppTypography.inter(
                    color: KeroseneBrandTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ) ??
      false;

  if (!confirmed) return false;
  await markOnchainSendAddressKnown(trimmed, prefs: prefs);
  return true;
}

String _title(BuildContext context) => context.tr.firstSendConfirmTitle;

String _body(BuildContext context, String preview) =>
    context.tr.firstSendConfirmBody(preview);

String _cancel(BuildContext context) => context.tr.cancel;

String _confirm(BuildContext context) => context.tr.firstSendConfirmAction;
