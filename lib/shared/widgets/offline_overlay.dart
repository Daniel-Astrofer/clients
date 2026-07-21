import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

class OfflineOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineOverlay({super.key, required this.child});

  @override
  ConsumerState<OfflineOverlay> createState() => _OfflineOverlayState();
}

class _OfflineOverlayState extends ConsumerState<OfflineOverlay>
    with TickerProviderStateMixin {
  static const int _maxAutomaticRetries = 5;

  late final AnimationController _pulseController;
  late final AnimationController _retryController;
  Timer? _retryTimer;
  int _retryCount = 0;

  /// User dismissed the blocking sheet to browse cached balances.
  bool _dismissedForReadOnly = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.loop,
    )..repeat();
    _retryController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.offlineRetryPulse,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRetryLoop());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pulseController.dispose();
    _retryController.dispose();
    super.dispose();
  }

  void _syncRetryLoop() {
    final isOnline = ref.read(networkStatusProvider);
    if (isOnline) {
      _stopRetryLoop();
      if ((_retryCount != 0 || _dismissedForReadOnly) && mounted) {
        setState(() {
          _retryCount = 0;
          _dismissedForReadOnly = false;
        });
      }
      return;
    }
    if (_retryCount >= _maxAutomaticRetries) {
      _stopRetryLoop();
      return;
    }
    _retryTimer ??= Timer.periodic(KeroseneMotion.offlineRetryInterval, (_) {
      if (!mounted) return;
      _performRetry();
    });
  }

  Future<void> _performRetry({bool manual = false}) async {
    if (!mounted) return;
    if (!manual && _retryCount >= _maxAutomaticRetries) {
      _stopRetryLoop();
      return;
    }

    setState(() => _retryCount += 1);
    _retryController.forward(from: 0);
    await ref.read(networkStatusProvider.notifier).checkConnection();
    if (!mounted) return;
    if (!manual && _retryCount >= _maxAutomaticRetries) {
      _stopRetryLoop();
    }
  }

  void _stopRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  String _body(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' =>
        'Connection to the backend was lost. We will retry for a limited time. You can still browse cached balances.',
      'es' =>
        'Se perdió la conexión con el backend. Reintentaremos por un tiempo limitado. Aún puedes ver saldos en caché.',
      _ =>
        'A conexão com o backend caiu. Tentaremos reconectar por tempo limitado. Você ainda pode ver saldos em cache.',
    };
  }

  String _retryNow(BuildContext context) {
    return context.tr.offlineTryNow;
  }

  String _browseCached(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => 'Browse offline (cached)',
      'es' => 'Ver sin conexión (caché)',
      _ => 'Navegar offline (cache)',
    };
  }

  String _retryHint(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    if (_retryCount == 0) {
      return switch (lang) {
        'en' =>
          'We will automatically retry up to $_maxAutomaticRetries times.',
        'es' =>
          'Reintentaremos automáticamente hasta $_maxAutomaticRetries veces.',
        _ => 'Tentaremos automaticamente até $_maxAutomaticRetries vezes.',
      };
    }
    if (_retryCount >= _maxAutomaticRetries) {
      return switch (lang) {
        'en' =>
          'Automatic retries paused. Use Try again to check connectivity.',
        'es' =>
          'Reintentos automáticos en pausa. Usa Reintentar para comprobar de nuevo.',
        _ => context.tr.offlineSubtitle,
      };
    }
    return switch (lang) {
      'en' => 'Attempt $_retryCount of $_maxAutomaticRetries sent.',
      'es' => 'Intento $_retryCount de $_maxAutomaticRetries enviado.',
      _ => 'Tentativa $_retryCount de $_maxAutomaticRetries enviada.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(networkStatusProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRetryLoop());

    final showBlocking = !isOnline && !_dismissedForReadOnly;
    final showBanner = !isOnline && _dismissedForReadOnly;

    return RepaintBoundary(
      child: Stack(
        children: [
          widget.child,
          if (showBanner)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 8,
              child: Material(
                color: KeroseneBrandTokens.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        KeroseneIcons.wifiOff,
                        size: 18,
                        color: KeroseneBrandTokens.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          switch (
                              Localizations.localeOf(context).languageCode) {
                            'en' => 'Offline · showing cached data',
                            'es' => 'Sin conexión · datos en caché',
                            _ => 'Offline · exibindo dados em cache',
                          },
                          style: TextStyle(
                            color: KeroseneBrandTokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _performRetry(manual: true),
                        child: Text(
                          _retryNow(context),
                          style: TextStyle(
                            color: KeroseneBrandTokens.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (showBlocking)
            Positioned.fill(
              child: Material(
                color: KeroseneBrandTokens.background.withValues(alpha: 0.94),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final iconSize =
                          math.min(148.0, math.max(104.0, width * 0.34));
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AnimatedConnectionIcon(
                                  pulse: _pulseController,
                                  retry: _retryController,
                                  retryCount: _retryCount,
                                  size: iconSize,
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  context.tr.offlineTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: KeroseneBrandTokens.textPrimary,
                                    fontSize: math.min(
                                        30, math.max(22, width * 0.07)),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                    fontFamily: AppTypography.displayFontFamily,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _body(context),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: KeroseneBrandTokens.textMuted,
                                    fontSize: math.min(
                                        16, math.max(13, width * 0.038)),
                                    height: 1.45,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                AppButton(
                                  label: _retryNow(context),
                                  onPressed: () => _performRetry(manual: true),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    setState(
                                        () => _dismissedForReadOnly = true);
                                  },
                                  child: Text(
                                    _browseCached(context),
                                    style: TextStyle(
                                      color: KeroseneBrandTokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _retryHint(context),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: KeroseneBrandTokens.textMuted
                                        .withValues(alpha: 0.78),
                                    fontSize: 12,
                                    height: 1.35,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedConnectionIcon extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController retry;
  final int retryCount;
  final double size;

  const _AnimatedConnectionIcon({
    required this.pulse,
    required this.retry,
    required this.retryCount,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, retry]),
      builder: (context, _) {
        final idle = (math.sin(pulse.value * math.pi * 2) + 1) / 2;
        final hit = retry.isAnimating
            ? KeroseneMotion.expressiveBack.transform(retry.value)
            : 0.0;
        final direction = retryCount.isEven ? -1.0 : 1.0;
        final retryGlow = hit * (0.10 + (retryCount % 3) * 0.035);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var index = 0; index < 3; index++)
                Transform.scale(
                  scale: 0.76 + index * 0.18 + idle * 0.06 + hit * 0.05,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: KeroseneBrandTokens.warning.withValues(
                          alpha: 0.08 + index * 0.05 + retryGlow,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(direction * hit * size * 0.08, 0),
                child: Transform.rotate(
                  angle: direction * hit * 0.14,
                  child: Container(
                    width: size * 0.72,
                    height: size * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          KeroseneBrandTokens.surface.withValues(alpha: 0.96),
                      border: Border.all(
                        color: KeroseneBrandTokens.warning.withValues(
                          alpha: 0.28 + retryGlow,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: KeroseneBrandTokens.warning.withValues(
                            alpha: 0.12 + idle * 0.10 + retryGlow,
                          ),
                          blurRadius: 32 + hit * 12,
                          spreadRadius: 2 + hit * 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      KeroseneIcons.wifiOff,
                      size: size * 0.34,
                      color: KeroseneBrandTokens.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
