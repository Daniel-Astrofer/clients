import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/home/presentation/screens/qr_scanner_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_availability_provider.dart';
import 'package:kerosene/shared/widgets/nfc_scan_dialog.dart';

/// Bottom sheet: scan QR, read NFC (when available), or paste clipboard.
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
    final tokens = SendFlowTheme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceMd,
          0,
          tokens.spaceMd,
          tokens.spaceMd,
        ),
        child: Material(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLg - 4,
              tokens.spaceMd - 4,
              tokens.spaceLg - 4,
              tokens.spaceLg - 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.textPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                Text(
                  _title(context),
                  style: AppTypography.newsreader(
                    color: tokens.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: tokens.spaceSm - 2),
                Text(
                  _subtitle(context, includeNfc: nfcSupported),
                  style: AppTypography.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                _CaptureOption(
                  icon: KeroseneIcons.scanner,
                  title: _qrTitle(context),
                  subtitle: _qrSubtitle(context),
                  onTap: () => _pickQr(context),
                ),
                if (nfcSupported) ...[
                  SizedBox(height: tokens.spaceSm),
                  _CaptureOption(
                    icon: KeroseneIcons.nfc,
                    title: _nfcTitle(context),
                    subtitle: _nfcSubtitle(context),
                    onTap: () => _pickNfc(context),
                  ),
                ],
                SizedBox(height: tokens.spaceSm),
                _CaptureOption(
                  icon: Icons.content_paste_rounded,
                  title: _pasteTitle(context),
                  subtitle: _pasteSubtitle(context),
                  onTap: () => _pickPaste(context),
                ),
                SizedBox(height: tokens.spaceSm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr.cancel,
                    style: AppTypography.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  String _subtitle(BuildContext context, {required bool includeNfc}) =>
      switch (_lang(context)) {
        'en' => includeNfc
            ? 'Scan a QR code, tap an NFC tag, or paste from the clipboard.'
            : 'Scan a QR code or paste from the clipboard.',
        'es' => includeNfc
            ? 'Escanea un código QR, acerca una etiqueta NFC o pega del portapapeles.'
            : 'Escanea un código QR o pega del portapapeles.',
        _ => includeNfc
            ? 'Escaneie um QR code, aproxime uma etiqueta NFC ou cole da área de transferência.'
            : 'Escaneie um QR code ou cole da área de transferência.',
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

  const _CaptureOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);

    return Material(
      color: SendFlowTheme.of(context).surfaceHigh,
      borderRadius: BorderRadius.circular(tokens.radiusInput + 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusInput + 2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceMd - 2,
            vertical: tokens.spaceMd - 2,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tokens.textPrimary, size: 22),
              ),
              SizedBox(width: tokens.spaceMd - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.inter(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
