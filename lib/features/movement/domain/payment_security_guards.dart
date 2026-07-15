import 'package:flutter/material.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kFirstSendAddressesPrefsKey = 'payment.first_send_addresses_v1';

/// App default network for local/test deployments (testnet4 addresses are tb1…).
/// Mainnet builds can override via [expectedBitcoinNetworkOverride].
BitcoinNetworkKind expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;

BitcoinNetworkKind get expectedBitcoinNetwork => expectedBitcoinNetworkOverride;

/// Returns a human error if [address] is incompatible with the app network.
String? networkMismatchMessage(String address) {
  final expected = expectedBitcoinNetwork;
  if (expected == BitcoinNetworkKind.unknown) return null;
  if (!looksLikeBitcoinAddress(address)) return null;
  if (isBitcoinAddressCompatibleWithNetwork(address, expected)) return null;
  final detected = inferBitcoinNetworkFromAddress(address);
  return 'Rede do endereço (${bitcoinNetworkDisplayName(detected)}) '
      'não confere com a rede do app (${bitcoinNetworkDisplayName(expected)}).';
}

/// Confirms first-time on-chain destinations (address poisoning mitigation).
Future<bool> confirmFirstTimeOnchainAddress({
  required BuildContext context,
  required String address,
  SharedPreferences? prefs,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty || !looksLikeBitcoinAddress(trimmed)) {
    return true;
  }

  final storage = prefs ?? await SharedPreferences.getInstance();
  final known = storage.getStringList(kFirstSendAddressesPrefsKey) ?? const [];
  final key = normalizeBitcoinAddressForDisplay(trimmed).toLowerCase();
  if (known.any((e) => e.toLowerCase() == key)) {
    return true;
  }

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final head = trimmed.length <= 12
              ? trimmed
              : '${trimmed.substring(0, 8)}…${trimmed.substring(trimmed.length - 6)}';
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

  final next = {...known, key}.toList(growable: false);
  // Cap list size.
  final capped = next.length > 200 ? next.sublist(next.length - 200) : next;
  await storage.setStringList(kFirstSendAddressesPrefsKey, capped);
  return true;
}

String _title(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => 'Confirm address',
      'es' => 'Confirmar dirección',
      _ => 'Confirmar endereço',
    };

String _body(BuildContext context, String preview) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' =>
        'First time sending to this address. Check the first and last characters carefully:\n\n$preview',
      'es' =>
        'Primera vez que envías a esta dirección. Revisa los primeros y últimos caracteres:\n\n$preview',
      _ =>
        'Primeira vez enviando para este endereço. Confira com atenção o início e o fim:\n\n$preview',
    };

String _cancel(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => 'Cancel',
      'es' => 'Cancelar',
      _ => 'Cancelar',
    };

String _confirm(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => 'Looks correct',
      'es' => 'Está correcto',
      _ => 'Está correto',
    };
