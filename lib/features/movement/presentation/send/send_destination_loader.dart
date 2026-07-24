import 'package:flutter/material.dart';

import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

/// Nubank-style sequential loading screen shown when a payment link,
/// on-chain address, BOLT11 invoice, or wallet hash is pasted/scanned
/// in the send flow.
///
/// Displays three serif text phases in sequence while background
/// resolution work runs in parallel via [onResolve].  The overlay
/// auto-dismisses once the animation sequence finishes *and*
/// [onResolve] completes successfully.
class SendDestinationLoader extends StatefulWidget {
  /// Async work that resolves the pasted destination (network lookups,
  /// rail selection, etc.).  Returns `true` on success, `false` on
  /// recoverable failure (the overlay stays up, callers should show an
  /// error and pop), or throws for fatal failures.
  final Future<bool> Function() onResolve;

  const SendDestinationLoader({required this.onResolve, super.key});

  @override
  State<SendDestinationLoader> createState() => _SendDestinationLoaderState();
}

class _SendDestinationLoaderState extends State<SendDestinationLoader>
    with SingleTickerProviderStateMixin {
  // ---- phase constants ----
  static const _phases = <String>[
    'Procurando destino',
    'Analisando endereço',
    'Analisando valor',
  ];

  static const _phaseAdvanceMs = 1500;
  static const _dismissDelayMs = 380;

  // ---- state ----
  int _phase = 0;
  bool _resolved = false;
  String? _errorMessage;

  // ---- animation controllers ----
  late final AnimationController _textFade;
  late final Animation<double> _textOpacity;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _textFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _textOpacity = CurvedAnimation(parent: _textFade, curve: Curves.easeInOut);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Phase 0 text fades in immediately.
    _textFade.forward();

    _advancePhases();
    _startResolution();
  }

  @override
  void dispose() {
    _textFade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ---- phase sequencer ----

  Future<void> _advancePhases() async {
    for (var i = 1; i < _phases.length; i++) {
      await Future<void>.delayed(
        const Duration(milliseconds: _phaseAdvanceMs),
      );
      if (!mounted) return;
      // Cross-fade: fade out, swap text, fade in.
      await _textFade.reverse();
      if (!mounted) return;
      setState(() => _phase = i);
      _textFade.forward();
    }
  }

  // ---- background resolution ----

  Future<void> _startResolution() async {
    try {
      final success = await widget.onResolve();
      if (!mounted) return;
      setState(() => _resolved = true);

      if (success) {
        // Brief settling moment so the final phase is visible.
        await Future<void>.delayed(
          const Duration(milliseconds: _dismissDelayMs),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage =
            'Não foi possível processar o destino. Verifique e tente novamente.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Erro ao analisar o destino. Tente novamente.');
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;

    return PopScope(
      canPop: false,
      child: Material(
        color: surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- phase text ----
              FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  _phases[_phase],
                  textAlign: TextAlign.center,
                  style: HomeTypography.heroTitle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.88),
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ---- activity indicator ----
              if (!_resolved && _errorMessage == null)
                FadeTransition(
                  opacity: _pulse,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // ---- error state ----
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: HomeTypography.bodyText(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Tentar novamente',
                    style: HomeTypography.buttonLabel(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
