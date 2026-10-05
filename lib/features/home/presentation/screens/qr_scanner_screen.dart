import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kerosene/core/constants/localized_copy.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String value) {
    if (_hasScanned || value.trim().isEmpty || !mounted) return;
    _hasScanned = true;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value.trim());
  }

  Future<void> _paste() async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (value?.text?.trim().isNotEmpty == true) {
      _finish(value!.text!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        const LocalizedCopy(
                en: 'Nothing to paste.',
                pt: 'Nada para colar.',
                es: 'No hay nada que pegar.')
            .resolve(context),
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.hexFF000000,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) _finish(barcode.rawValue!);
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(KeroseneIcons.warning,
                      color: AppColors.hexFFFFFFFF, size: 36),
                  const SizedBox(height: 16),
                  Text(
                      const LocalizedCopy(
                        en: 'Camera unavailable. Allow camera access in your device settings, or paste the payment details.',
                        pt: 'Câmera indisponível. Permita o acesso nas configurações do aparelho ou cole os dados do pagamento.',
                        es: 'Cámara no disponible. Permite el acceso en los ajustes del dispositivo o pega los datos del pago.',
                      ).resolve(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.hexFFFFFFFF)),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () async {
                        try {
                          await _controller.start();
                        } catch (_) {/* errorBuilder retains the recovery UI */}
                      },
                      child: Text(context.tr.tryAgain)),
                ]),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) => state.error != null
                ? const SizedBox.shrink()
                : IgnorePointer(
                    child: Center(
                        child: FractionallySizedBox(
                    widthFactor: 0.7,
                    child: AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.hexFFFFFFFF
                                    .withValues(alpha: 0.85),
                                width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        )),
                  ))),
          ),
          SafeArea(
              child: Column(children: [
            Material(
                color: AppColors.hexFF000000.withValues(alpha: 0.6),
                child: Row(children: [
                  BackButton(color: AppColors.hexFFFFFFFF),
                  Expanded(
                      child: Text(context.tr.scanQR,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.hexFFFFFFFF))),
                  IconButton(
                      tooltip: const LocalizedCopy(
                              en: 'Flashlight', pt: 'Lanterna', es: 'Linterna')
                          .resolve(context),
                      onPressed: () => _controller.toggleTorch(),
                      icon: const Icon(KeroseneIcons.lightning,
                          color: AppColors.hexFFFFFFFF)),
                  IconButton(
                      tooltip: const LocalizedCopy(
                              en: 'Switch camera',
                              pt: 'Trocar câmera',
                              es: 'Cambiar cámara')
                          .resolve(context),
                      onPressed: () => _controller.switchCamera(),
                      icon: const Icon(KeroseneIcons.refresh,
                          color: AppColors.hexFFFFFFFF)),
                ])),
            const Spacer(),
            Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(context.tr.qrScannerInstruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.hexFFFFFFFF)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _paste,
                      icon: const Icon(KeroseneIcons.paste),
                      label: Text(const LocalizedCopy(
                              en: 'Paste payment details',
                              pt: 'Colar dados do pagamento',
                              es: 'Pegar datos del pago')
                          .resolve(context))),
                ])),
          ])),
        ],
      ),
    );
  }
}
