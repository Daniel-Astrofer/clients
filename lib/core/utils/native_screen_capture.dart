import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kerosene/core/debug/device_screen_gallery_export.dart';
import 'package:kerosene/core/debug/device_ui_snapshot.dart';

/// Debug overlay: **DADOS** exports session JSON **and** PNG screenshots.
class ScreenCaptureConfig {
  ScreenCaptureConfig._();

  static const bool _flagOn = bool.fromEnvironment(
    'SCREEN_CAPTURE_UI',
    defaultValue: false,
  );
  static const bool _flagExplicit = bool.hasEnvironment('SCREEN_CAPTURE_UI');

  static bool get enabled {
    if (_flagExplicit) return _flagOn;
    if (kIsWeb) return false;
    if (!kDebugMode) return false;
    return Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isAndroid;
  }

  static void logStatus() {
    if (!kDebugMode) return;
    debugPrint(
      '[screen-capture] enabled=$enabled '
      '(DADOS → JSON + PNG gallery)',
    );
  }
}

class ScreenCaptureHost extends StatelessWidget {
  final Widget child;
  final bool? enabled;

  const ScreenCaptureHost({
    super.key,
    required this.child,
    this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? ScreenCaptureConfig.enabled;
    if (!on) return child;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        const Positioned(
          top: 12,
          right: 12,
          child: SafeArea(child: _DadosButton()),
        ),
      ],
    );
  }
}

class _DadosButton extends ConsumerStatefulWidget {
  const _DadosButton();

  @override
  ConsumerState<_DadosButton> createState() => _DadosButtonState();
}

class _DadosButtonState extends ConsumerState<_DadosButton> {
  bool _busy = false;
  String _status = '';

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'preparando…';
    });
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      // Full pipeline: freeze session JSON + paint each screen to PNG.
      final result = await DeviceScreenGalleryExport.run(
        context: context,
        ref: ref,
        onStatus: (s) {
          if (!mounted) return;
          setState(() => _status = s);
        },
      );
      if (!mounted) return;
      final pngCount = result.pngs.length;
      final dir = result.directory.path;
      messenger?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 16),
          content: Text(
            'Captura OK: $pngCount PNGs + JSON\n'
            '$dir\n'
            '(${result.snapshot.wallets.length} wallets, '
            '${result.snapshot.transactions.length} txs)',
          ),
        ),
      );
      debugPrint(
        '[dados] gallery OK dir=$dir pngs=$pngCount '
        'json=${result.jsonFiles.map((f) => f.path).join(' | ')}',
      );
    } catch (e, st) {
      debugPrint('[dados] gallery FAIL: $e\n$st');
      // Fallback: at least export JSON if gallery paint fails.
      try {
        final files = await DeviceUiSnapshot.exportFromRef(ref);
        if (!mounted) return;
        messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 12),
            content: Text(
              'PNG falhou ($e). JSON salvo:\n${files.first.path}',
            ),
          ),
        );
      } catch (e2) {
        if (!mounted) return;
        messenger?.showSnackBar(
          SnackBar(content: Text('Falha ao exportar: $e')),
        );
        debugPrint('[dados] JSON fallback also failed: $e2');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: _busy ? const Color(0xFF555555) : const Color(0xFF0A84FF),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: _busy ? null : _run,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.photo_library_outlined,
                    color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'DADOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    _busy
                        ? (_status.isEmpty ? 'gerando PNGs…' : _status)
                        : 'JSON + imagens das telas',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
