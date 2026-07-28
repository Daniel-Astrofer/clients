import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/shader_provider.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

/// Full-screen GLSL shader execution animation overlay for payments and
/// destination validations.
///
/// Blurs the underlying screen, displays a loading state with bottom-anchored
/// GPU GLSL shader glow, and smoothly springs the shader to the top upon
/// confirmation while displaying success status with haptic feedback.
class SendPaymentExecutionOverlay extends ConsumerStatefulWidget {
  final Future<bool> Function() onExecute;
  final String loadingMessage;
  final String successMessage;
  final String errorMessage;
  final Duration successDelay;

  const SendPaymentExecutionOverlay({
    super.key,
    required this.onExecute,
    this.loadingMessage = 'Validando...',
    this.successMessage = 'Confirmada',
    this.errorMessage = 'Não foi possível processar',
    this.successDelay = const Duration(milliseconds: 1600),
  });

  static Future<bool?> show(
    BuildContext context, {
    required Future<bool> Function() onExecute,
    String loadingMessage = 'Validando...',
    String successMessage = 'Confirmada',
    String errorMessage = 'Não foi possível processar',
    Duration successDelay = const Duration(milliseconds: 1600),
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: KeroseneMotion.slow,
      pageBuilder: (context, anim1, anim2) => FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: KeroseneMotion.standard),
        child: SendPaymentExecutionOverlay(
          onExecute: onExecute,
          loadingMessage: loadingMessage,
          successMessage: successMessage,
          errorMessage: errorMessage,
          successDelay: successDelay,
        ),
      ),
    );
  }

  @override
  ConsumerState<SendPaymentExecutionOverlay> createState() =>
      _SendPaymentExecutionOverlayState();
}

class _SendPaymentExecutionOverlayState
    extends ConsumerState<SendPaymentExecutionOverlay>
    with SingleTickerProviderStateMixin {
  bool _isSuccess = false;
  bool _isError = false;
  String? _displayMessage;

  late final Ticker _ticker;
  double _timeSec = 0;
  Duration? _lastTick;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _displayMessage = widget.loadingMessage;
    _ticker = createTicker(_onTick)..start();
    HapticFeedback.mediumImpact();
    _runExecution();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == null) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _timeSec += dt;
    if (mounted) setState(() {});
  }

  void _bindShader(ui.FragmentProgram program) {
    if (_shader != null) return;
    _shader = program.fragmentShader();
  }

  Future<void> _runExecution() async {
    try {
      final success = await widget.onExecute();
      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();
        setState(() {
          _isSuccess = true;
          _displayMessage = widget.successMessage;
        });
        await Future<void>.delayed(widget.successDelay);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _isError = true;
          _displayMessage = widget.errorMessage;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(false);
      }
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _isError = true;
        _displayMessage = 'Erro ao processar.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(geminiGlowShaderProvider);
    final program = programAsync.asData?.value;
    if (program != null) {
      _bindShader(program);
    }

    final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background blur and dark atmosphere
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(
                color: surfaceColor.withValues(alpha: 0.78),
              ),
            ),

            // GLSL Shader Glow - Springing from bottom to top on confirmation
            AnimatedAlign(
              duration: const Duration(milliseconds: 850),
              curve: _isSuccess ? KeroseneMotion.spring : KeroseneMotion.standard,
              alignment:
                  _isSuccess ? Alignment.topCenter : Alignment.bottomCenter,
              child: SizedBox(
                height: 420,
                width: double.infinity,
                child: _shader == null
                    ? const SizedBox.shrink()
                    : RepaintBoundary(
                        child: CustomPaint(
                          painter: _ExecutionShaderPainter(
                            shader: _shader!,
                            timeSec: _timeSec,
                            intensity: _isSuccess ? 0.65 : 0.45,
                            primary: const Color(0xFF4D7EFF),
                            secondary: _isSuccess
                                ? const Color(0xFF37E28E) // Mint/Green on success
                                : const Color(0xFF9B7BFF),
                          ),
                        ),
                      ),
              ),
            ),

            // Center status content
            Center(
              child: AnimatedSwitcher(
                duration: KeroseneMotion.medium,
                switchInCurve: KeroseneMotion.entrance,
                switchOutCurve: KeroseneMotion.exit,
                child: _buildStatusContent(onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(Color onSurface) {
    if (_isSuccess) {
      return Row(
        key: const ValueKey('success_state'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: onSurface,
            size: 24,
          ),
          const SizedBox(width: 14),
          Text(
            _displayMessage ?? widget.successMessage,
            style: HomeTypography.heroTitle(
              color: onSurface,
              fontSize: 22,
            ),
          ),
        ],
      );
    }

    if (_isError) {
      return Row(
        key: const ValueKey('error_state'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 14),
          Text(
            _displayMessage ?? widget.errorMessage,
            style: HomeTypography.heroTitle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 22,
            ),
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey('loading_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: onSurface,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          _displayMessage ?? widget.loadingMessage,
          style: HomeTypography.heroTitle(
            color: onSurface.withValues(alpha: 0.92),
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}

class _ExecutionShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double timeSec;
  final double intensity;
  final Color primary;
  final Color secondary;

  const _ExecutionShaderPainter({
    required this.shader,
    required this.timeSec,
    required this.intensity,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeSec);
    shader.setFloat(3, 0.0);
    shader.setFloat(4, intensity);
    shader.setFloat(5, 0.45);
    shader.setFloat(6, 0.25);
    shader.setFloat(7, primary.r);
    shader.setFloat(8, primary.g);
    shader.setFloat(9, primary.b);
    shader.setFloat(10, primary.a);
    shader.setFloat(11, secondary.r);
    shader.setFloat(12, secondary.g);
    shader.setFloat(13, secondary.b);
    shader.setFloat(14, secondary.a);
    shader.setFloat(15, 0.0);
    shader.setFloat(16, size.height);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..isAntiAlias = true
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _ExecutionShaderPainter oldDelegate) {
    return oldDelegate.timeSec != timeSec ||
        oldDelegate.intensity != intensity ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.shader != shader;
  }
}
