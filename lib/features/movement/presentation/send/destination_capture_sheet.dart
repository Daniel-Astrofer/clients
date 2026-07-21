import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/home/presentation/screens/qr_scanner_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_availability_provider.dart';
import 'package:kerosene/shared/widgets/nfc_scan_dialog.dart';

/// Bottom sheet: scan QR, read NFC, or paste clipboard into the send destination field.
class DestinationCaptureSheet extends StatelessWidget {
  final bool nfcSupported;

  const DestinationCaptureSheet({
    super.key,
    required this.nfcSupported,
  });

  /// Shows the sheet and returns a non-empty payment payload, or null if cancelled.
  static Future<String?> show(BuildContext context,
      {bool? nfcSupported}) async {
    final supported = nfcSupported ?? await keroseneDeviceSupportsNfc();
    if (!context.mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) =>
          DestinationCaptureSheet(nfcSupported: supported),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: KeroseneBrandTokens.surface,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _title(context),
                  style: AppTypography.inter(
                    color: KeroseneBrandTokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(context),
                  style: AppTypography.inter(
                    color: KeroseneBrandTokens.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _CaptureOption(
                  icon: KeroseneIcons.scanner,
                  title: _qrTitle(context),
                  subtitle: _qrSubtitle(context),
                  onTap: () => _pickQr(context),
                ),
                const SizedBox(height: 8),
                _CaptureOption(
                  icon: KeroseneIcons.nfc,
                  title: _nfcTitle(context),
                  subtitle: nfcSupported
                      ? _nfcSubtitle(context)
                      : _nfcUnavailable(context),
                  enabled: nfcSupported,
                  onTap: nfcSupported ? () => _pickNfc(context) : null,
                ),
                const SizedBox(height: 8),
                _CaptureOption(
                  icon: Icons.content_paste_rounded,
                  title: _pasteTitle(context),
                  subtitle: _pasteSubtitle(context),
                  onTap: () => _pickPaste(context),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr.cancel,
                    style: AppTypography.inter(
                      color: KeroseneBrandTokens.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickQr(BuildContext context) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    final value = payload?.trim();
    if (!context.mounted) return;
    if (value == null || value.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(value);
  }

  Future<void> _pickNfc(BuildContext context) async {
    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const NfcScanDialog(),
    );
    final value = payload?.trim();
    if (!context.mounted) return;
    if (value == null || value.isEmpty) {
      // User cancelled or empty tag — keep sheet open? Pop with null.
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(value);
  }

  Future<void> _pickPaste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (value.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_clipboardEmpty(context))),
      );
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value);
  }

  String _title(BuildContext context) => switch (_lang(context)) {
        'en' => 'Add destination',
        'es' => 'Agregar destino',
        _ => 'Adicionar destino',
      };

  String _subtitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'Scan a QR code, tap an NFC tag, or paste from the clipboard.',
        'es' =>
          'Escanea un código QR, acerca una etiqueta NFC o pega del portapapeles.',
        _ =>
          'Escaneie um QR code, aproxime uma etiqueta NFC ou cole da área de transferência.',
      };

  String _qrTitle(BuildContext context) =>
      context.tr.scanQR.isNotEmpty ? context.tr.scanQR : 'QR code';

  String _qrSubtitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'Camera · payment link, address, or invoice',
        'es' => 'Cámara · link, dirección o invoice',
        _ => 'Câmera · link, endereço ou invoice',
      };

  String _nfcTitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'NFC',
        'es' => 'NFC',
        _ => 'NFC',
      };

  String _nfcSubtitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'Hold near a Kerosene payment tag',
        'es' => 'Acerca a una etiqueta de pago Kerosene',
        _ => 'Aproxime de uma etiqueta de pagamento Kerosene',
      };

  String _nfcUnavailable(BuildContext context) => switch (_lang(context)) {
        'en' => 'NFC is not available on this device',
        'es' => 'NFC no está disponible en este dispositivo',
        _ => 'NFC não está disponível neste aparelho',
      };

  String _pasteTitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'Paste',
        'es' => 'Pegar',
        _ => 'Colar',
      };

  String _pasteSubtitle(BuildContext context) => switch (_lang(context)) {
        'en' => 'Use text from the clipboard',
        'es' => 'Usar texto del portapapeles',
        _ => 'Usar texto da área de transferência',
      };

  String _clipboardEmpty(BuildContext context) => switch (_lang(context)) {
        'en' => 'Clipboard is empty.',
        'es' => 'El portapapeles está vacío.',
        _ => 'A área de transferência está vazia.',
      };

  String _lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;
}

class _CaptureOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _CaptureOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final muted = !enabled;
    final color = muted
        ? KeroseneBrandTokens.textMuted.withValues(alpha: 0.45)
        : KeroseneBrandTokens.textPrimary;
    final subColor = muted
        ? KeroseneBrandTokens.textMuted.withValues(alpha: 0.4)
        : KeroseneBrandTokens.textMuted;

    return Material(
      color: KeroseneBrandTokens.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KeroseneBrandTokens.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.inter(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.inter(
                        color: subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: subColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
