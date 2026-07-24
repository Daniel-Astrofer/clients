import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/shader_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_overscroll_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show HomeLedgerBalanceView, homeLedgerBalanceViewProvider;
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/aurora_interaction_provider.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';

/// GPU Gemini edge-glow — ambient aurora behind the home header.
///
/// Mounted inside the root aurora layer, behind the scrolling home body.
/// Colors / intensity / theater energy are continuously lerped so enter/exit
/// never flick.
class SceneGeminiGlowBackground extends ConsumerStatefulWidget {
  const SceneGeminiGlowBackground({super.key});

  @override
  ConsumerState<SceneGeminiGlowBackground> createState() =>
      _SceneGeminiGlowBackgroundState();
}

class _SceneGeminiGlowBackgroundState
    extends ConsumerState<SceneGeminiGlowBackground>
    with SingleTickerProviderStateMixin {
  // Visual (smoothed) state — only these feed the shader.
  Color _primary = const Color(0xFF4D7EFF);
  Color _secondary = const Color(0xFF9B7BFF);
  double _intensity = 0.42;
  double _theater = 0;
  double _surge = 0;
  double _pullVisual = 0;

  // Targets — updated by providers, never snapped into the shader.
  Color _primaryTarget = const Color(0xFF4D7EFF);
  Color _secondaryTarget = const Color(0xFF9B7BFF);
  double _intensityTarget = 0.42;
  double _theaterTarget = 0;
  double _pullTarget = 0;

  String _lastSceneId = '';
  bool _lastActive = false;
  bool _seeded = false;

  late final Ticker _ticker;
  double _seconds = 0;
  Duration? _lastTick;
  bool _ticking = false;

  ui.FragmentShader? _shader;

  static const _deadZonePx = 6.0;
  static const _fullBloomPx = 130.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureTicking();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureTicking();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (!mounted) return;
    final reduce = KeroseneMotion.reduceMotion(context);
    final enabled = TickerMode.valuesOf(context).enabled;
    final want = !reduce && enabled;
    if (want && !_ticking) {
      _lastTick = null;
      _ticker.start();
      _ticking = true;
    } else if (!want && _ticking) {
      _ticker.stop();
      _ticking = false;
      _lastTick = null;
    }
  }

  Color _lerpColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t.clamp(0.0, 1.0)) ?? b;
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    if (dt <= 0) return;

    // During pull (and theater), advance the aurora clock slower so waves
    // don't thrash — receive green used to look frenetic on bounce.
    final timeScale = (1.0 -
            0.40 * _pullVisual -
            0.28 * _theater.clamp(0.0, 1.0))
        .clamp(0.42, 1.0);
    _seconds += dt * timeScale;

    // Critically soft follow (dt-based) — kills frenetic vibration on bounce.
    final risingPull = _pullTarget > _pullVisual;
    // Theater: even softer pull follow so scroll bounce doesn't strobe green.
    final pullKBase = risingPull ? 2.2 : 1.5;
    final pullK = pullKBase * (1.0 - 0.35 * _theater.clamp(0.0, 1.0));
    final pullAlpha = (1.0 - _expNeg(pullK * dt)).clamp(0.0, 1.0);
    _pullVisual += (_pullTarget - _pullVisual) * pullAlpha;

    final risingTheater = _theaterTarget > _theater;
    final theaterK = risingTheater ? 1.6 : 1.4;
    final theaterAlpha = (1.0 - _expNeg(theaterK * dt)).clamp(0.0, 1.0);
    _theater += (_theaterTarget - _theater) * theaterAlpha;

    _intensity += (_intensityTarget - _intensity) * (1.0 - _expNeg(1.8 * dt));
    _primary = _lerpColor(_primary, _primaryTarget, 1.0 - _expNeg(1.6 * dt));
    _secondary =
        _lerpColor(_secondary, _secondaryTarget, 1.0 - _expNeg(1.6 * dt));

    // Soft exponential surge decay (enter bloom).
    if (_surge > 0.001) {
      _surge *= mathExpDecay(dt, halfLife: 0.45);
      if (_surge < 0.004) _surge = 0;
    }

    if ((_pullTarget - _pullVisual).abs() < 0.004) {
      _pullVisual = _pullTarget;
    }
    if ((_theaterTarget - _theater).abs() < 0.004) {
      _theater = _theaterTarget;
    }
    if ((_intensityTarget - _intensity).abs() < 0.004) {
      _intensity = _intensityTarget;
    }

    if (mounted) setState(() {});
  }

  double _expNeg(double x) {
    // Fast approx for e^-x in the small-x regime used here.
    final t = x.clamp(0.0, 8.0);
    return 1.0 /
        (1.0 + t + (t * t) / 2.0 + (t * t * t) / 6.0 + (t * t * t * t) / 24.0);
  }

  /// Approx. exp decay via half-life (seconds).
  double mathExpDecay(double dt, {required double halfLife}) {
    final k = 0.693147 / halfLife.clamp(0.05, 8.0);
    return (1.0 - (k * dt).clamp(0.0, 0.95));
  }

  void _syncPull(double overscrollPx) {
    final raw = ((overscrollPx - _deadZonePx) / _fullBloomPx).clamp(0.0, 1.0);
    // Ease the target itself so bounce chatter never spikes the shader.
    final eased = raw <= 0 ? 0.0 : Curves.easeOutCubic.transform(raw);
    // During theater, pull barely moves — green receive + bounce was strobing.
    final follow = _lerpDouble(0.35, 0.12, _theater.clamp(0.0, 1.0));
    _pullTarget = _pullTarget + (eased - _pullTarget) * follow;
    if (eased == 0 && _pullTarget < 0.02) _pullTarget = 0;
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  void _applySceneTargets(HomeScene scene) {
    final bg = scene.background;
    final theaterPiece = scene.hasForegroundContent;

    if (theaterPiece) {
      _primaryTarget = bg.primary ?? _primaryTarget;
      _secondaryTarget = bg.secondary ?? const Color(0xFF6B8CFF);
      // Same ceiling as resting wash — tint via uTheater, not raw intensity.
      _intensityTarget =
          (bg.intensity.clamp(0.30, 0.48) * 0.95).clamp(0.30, 0.52);
      // Partial theater channel: color shift without neon takeover.
      _theaterTarget = 0.42;
    } else {
      // Resting / wallet wash — keep field alive, dim theater channel.
      try {
        final view = ref.read(homeLedgerBalanceViewProvider);
        final wash = restingWashAccentFor(view);
        _primaryTarget = bg.primary ?? wash;
        // Prefer ledger wash when scene still carries default blue.
        if (bg.primary == null || scene.id == 'resting' || scene.id == 'idle') {
          _primaryTarget = wash;
        }
        // Onchain: warm orange companion — never purple (reads pink on amber).
        if (view == HomeLedgerBalanceView.onChain) {
          _primaryTarget = wash;
          _secondaryTarget = restingWashSecondaryFor(view);
        } else {
          _secondaryTarget = bg.secondary ??
              (Color.lerp(_primaryTarget, const Color(0xFF9B7BFF), 0.4) ??
                  const Color(0xFF9B7BFF));
        }
      } catch (_) {
        _primaryTarget = bg.primary ?? const Color(0xFF4D7EFF);
        _secondaryTarget = bg.secondary ?? const Color(0xFF9B7BFF);
      }
      final base = bg.isActive ? bg.intensity : 0.36;
      _intensityTarget = (base * 0.95).clamp(0.32, 0.58);
      _theaterTarget = 0.0;
    }

    final id = scene.id;
    final wasTheater = _lastActive;
    if (theaterPiece &&
        (!wasTheater || (id.isNotEmpty && id != _lastSceneId))) {
      // Soft enter bloom — avoid stacked surge + pull strobe on receive green.
      _surge = (_surge * 0.25 + 0.32).clamp(0.0, 0.45);
      ref.read(homeAuroraInteractionProvider).pulseFromScene(strength: 0.4);
    } else if (wasTheater && !theaterPiece) {
      // Exit handled by theaterTarget→0 lerp; tiny residual glow.
      _surge = (_surge * 0.35).clamp(0.0, 0.2);
    }
    _lastSceneId = id;
    _lastActive = theaterPiece;
  }

  void _bindShader(ui.FragmentProgram program) {
    if (_shader != null) return;
    _shader = program.fragmentShader();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<double>(homeOverscrollProvider, (_, next) {
      _syncPull(next);
    });

    ref.listen<HomeScene>(homeSceneProvider, (_, next) {
      _applySceneTargets(next);
    });

    ref.listen(homeLedgerBalanceViewProvider, (prev, next) {
      if (prev == next) return;
      final scene = ref.read(homeSceneProvider);
      // Scene notifier retints resting aurora; we only add a soft pulse.
      if (!scene.hasForegroundContent) {
        _surge = (_surge * 0.25 + 0.45).clamp(0.0, 0.8);
      }
    });

    // One-shot seed (listens handle subsequent updates — avoid per-build resets).
    if (!_seeded) {
      _seeded = true;
      _applySceneTargets(ref.read(homeSceneProvider));
    }

    final programAsync = ref.watch(geminiGlowShaderProvider);
    final program = programAsync.asData?.value;
    if (program == null) {
      return const SizedBox.shrink();
    }
    _bindShader(program);
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();

    // Fills the header stack — scrolls with the balance (same parent offset).
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _GeminiGlowShaderPainter(
            shader: shader,
            timeSec: _seconds,
            pull: _pullVisual.clamp(0.0, 1.0),
            intensity: _intensity.clamp(0.0, 1.0),
            theater: _theater.clamp(0.0, 1.0),
            surge: _surge.clamp(0.0, 1.0),
            primary: _primary,
            secondary: _secondary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GeminiGlowShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double timeSec;
  final double pull;
  final double intensity;
  final double theater;
  final double surge;
  final Color primary;
  final Color secondary;

  const _GeminiGlowShaderPainter({
    required this.shader,
    required this.timeSec,
    required this.pull,
    required this.intensity,
    required this.theater,
    required this.surge,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Uniform order must match gemini_glow.frag:
    // 0-1 uSize, 2 uTime, 3 uPull, 4 uIntensity, 5 uTheater, 6 uSurge,
    // 7-10 uPrimary, 11-14 uSecondary
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeSec);
    shader.setFloat(3, pull);
    shader.setFloat(4, intensity);
    shader.setFloat(5, theater);
    shader.setFloat(6, surge);
    shader.setFloat(7, primary.r);
    shader.setFloat(8, primary.g);
    shader.setFloat(9, primary.b);
    shader.setFloat(10, primary.a);
    shader.setFloat(11, secondary.r);
    shader.setFloat(12, secondary.g);
    shader.setFloat(13, secondary.b);
    shader.setFloat(14, secondary.a);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..isAntiAlias = true
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GeminiGlowShaderPainter oldDelegate) {
    return oldDelegate.timeSec != timeSec ||
        oldDelegate.pull != pull ||
        oldDelegate.intensity != intensity ||
        oldDelegate.theater != theater ||
        oldDelegate.surge != surge ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.shader != shader;
  }
}
