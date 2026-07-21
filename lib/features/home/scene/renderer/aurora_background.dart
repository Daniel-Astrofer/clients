import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/features/home/presentation/providers/home_overscroll_provider.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';

/// Edge-wave aurora — **the** home background glow.
///
/// Fixed in the upper band (status → mid-balance). Pull only intensifies the
/// same field — never translates or stretches the band. Soft Gemini-like
/// ribbons leave the side edges and travel inward; no linear fade slab.
class SceneAuroraBackground extends ConsumerStatefulWidget {
  const SceneAuroraBackground({super.key});

  @override
  ConsumerState<SceneAuroraBackground> createState() =>
      _SceneAuroraBackgroundState();
}

class _SceneAuroraBackgroundState extends ConsumerState<SceneAuroraBackground>
    with SingleTickerProviderStateMixin {
  Color _primary = const Color(0xFF4D7EFF);
  Color _secondary = const Color(0xFF9B7BFF);
  double _baseIntensity = 0.36;
  double _topInset = 0;

  Color? _wantPrimary;
  Color? _wantSecondary;
  double? _wantIntensity;
  double? _wantTopInset;
  bool _applyScheduled = false;

  late final Ticker _ticker;
  double _seconds = 0;
  Duration? _lastTick;
  bool _ticking = false;

  /// Smoothed pull 0→1 (intensity / energy only).
  double _pullVisual = 0;
  double _pullTarget = 0;

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
    super.dispose();
  }

  bool _nearColor(Color a, Color b) =>
      (a.r - b.r).abs() < 0.02 &&
      (a.g - b.g).abs() < 0.02 &&
      (a.b - b.b).abs() < 0.02 &&
      (a.a - b.a).abs() < 0.02;

  void _schedulePalette({
    required Color primary,
    required Color secondary,
    required double intensity,
    required double topInset,
  }) {
    _wantPrimary = primary;
    _wantSecondary = secondary;
    _wantIntensity = intensity;
    _wantTopInset = topInset;
    if (_applyScheduled) return;
    _applyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScheduled = false;
      if (!mounted) return;
      final p = _wantPrimary;
      final s = _wantSecondary;
      final i = _wantIntensity;
      final t = _wantTopInset;
      if (p == null || s == null || i == null || t == null) return;
      if (_nearColor(_primary, p) &&
          _nearColor(_secondary, s) &&
          (_baseIntensity - i).abs() < 0.015 &&
          (_topInset - t).abs() < 0.5) {
        return;
      }
      setState(() {
        _primary = p;
        _secondary = s;
        _baseIntensity = i;
        _topInset = t;
      });
    });
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

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    if (dt <= 0) return;

    _seconds += dt;

    final rising = _pullTarget > _pullVisual;
    final alpha = rising ? 0.34 : 0.12;
    _pullVisual += (_pullTarget - _pullVisual) * alpha;
    if ((_pullTarget - _pullVisual).abs() < 0.002) {
      _pullVisual = _pullTarget;
    }

    if (mounted) setState(() {});
  }

  void _syncPull(double overscrollPx) {
    final raw = ((overscrollPx - _deadZonePx) / _fullBloomPx).clamp(0.0, 1.0);
    _pullTarget = raw <= 0 ? 0.0 : Curves.easeOutCubic.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<double>(homeOverscrollProvider, (_, next) {
      _syncPull(next);
    });

    final bg = ref.watch(homeSceneBackgroundProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    if (!bg.isActive || bg.type == SceneBackgroundType.none) {
      return const SizedBox.shrink();
    }

    final sceneIntensity =
        (bg.intensity.clamp(0.28, 0.75) * 0.72).clamp(0.22, 0.55);
    _schedulePalette(
      primary: bg.primary ?? const Color(0xFF4D7EFF),
      secondary: bg.secondary ?? const Color(0xFF9B7BFF),
      intensity: sceneIntensity,
      topInset: topInset,
    );

    final pull = _pullVisual.clamp(0.0, 1.0);

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _EdgeWaveAuroraPainter(
            timeSec: _seconds,
            pull: pull,
            primary: _primary,
            secondary: _secondary,
            baseIntensity: _baseIntensity,
            topInset: _topInset,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EdgeWaveAuroraPainter extends CustomPainter {
  final double timeSec;
  final double pull;
  final Color primary;
  final Color secondary;
  final double baseIntensity;
  final double topInset;

  const _EdgeWaveAuroraPainter({
    required this.timeSec,
    required this.pull,
    required this.primary,
    required this.secondary,
    required this.baseIntensity,
    required this.topInset,
  });

  static const _hazeStops = [0.0, 0.22, 0.48, 0.72, 0.9, 1.0];

  /// Logical band: status bar → mid-balance. Fixed px, not % of screen height.
  /// Pull must never change this.
  double _bandBottom(double topInset) => topInset + 208;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final bandBottom = _bandBottom(topInset);
    if (bandBottom <= 8) return;
    // Glow lives in a fixed logical height (mid-balance), not % of screen.
    final bandH = math.max(120.0, bandBottom - topInset * 0.15);

    // Soft clip to upper band only — hard rect, no linear fade paint.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, bandBottom + 24));

    final energy =
        ((baseIntensity / 0.4) * (1.0 + 0.55 * pull)).clamp(0.55, 1.7);
    final speedBoost = 1.0 + 0.85 * pull;
    final ampBoost = 1.0 + 0.35 * pull;

    final cyan = Color.lerp(primary, const Color(0xFF5EC8E8), 0.58)!;
    final violet = Color.lerp(secondary, const Color(0xFFC4B5FD), 0.45)!;
    final mint = Color.lerp(secondary, const Color(0xFF5EEAD4), 0.42)!;
    final rose = Color.lerp(primary, const Color(0xFFF0ABFC), 0.35)!;
    final sky = Color.lerp(cyan, const Color(0xFF7DD3FC), 0.4)!;

    final hazeColors = List<Color>.filled(6, const Color(0x00000000));

    void haze(Offset c, double r, Color color, double peak) {
      if (r <= 1 || peak <= 0.008) return;
      // Soften blobs that sit near the band floor (local, not a screen wash).
      final yNorm = ((c.dy - topInset * 0.1) / bandH).clamp(0.0, 1.15);
      final depth = (1.0 - ((yNorm - 0.62) / 0.48).clamp(0.0, 1.0));
      final soft = depth * depth * (3 - 2 * depth);
      final a = peak * (0.55 + 0.45 * soft);
      if (a <= 0.008) return;
      hazeColors[0] = color.withValues(alpha: a * 0.55);
      hazeColors[1] = color.withValues(alpha: a * 0.42);
      hazeColors[2] = color.withValues(alpha: a * 0.26);
      hazeColors[3] = color.withValues(alpha: a * 0.12);
      hazeColors[4] = color.withValues(alpha: a * 0.04);
      hazeColors[5] = color.withValues(alpha: 0);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(c, r, hazeColors, _hazeStops),
      );
    }

    // Tall crest near edges → travels toward center (Gemini-like).
    double edgeTallness(double xNorm) {
      final d = (xNorm - 0.5).abs() * 2; // 0 center → 1 edge
      return 0.28 + 0.72 * (d * d);
    }

    // Inward travel envelope: crests born at edges, pass through middle.
    double travelPulse(double xNorm, double t, double phase,
        {required bool fromLeft}) {
      final origin = fromLeft ? 0.0 : 1.0;
      final signed = fromLeft ? xNorm : (1.0 - xNorm);
      // Moving front: peaks leave the edge and sweep inward.
      final front = (signed - (t * 0.085 + phase) % 1.35 + 0.15);
      final lobe = math.exp(-((front - 0.35) * (front - 0.35)) / 0.08);
      final edgeBias = math.exp(-((xNorm - origin).abs() * 2.2));
      return 0.35 + 0.65 * lobe + 0.25 * edgeBias;
    }

    void paintRibbon({
      required bool fromLeft,
      required Color color,
      required double baseYNorm,
      required double ampPx,
      required double freq,
      required double phase,
      required double speed,
      required double peak,
      required double radiusScale,
      int samples = 28,
    }) {
      final t = timeSec * speed * speedBoost + phase;
      for (var i = 0; i <= samples; i++) {
        final u = i / samples;
        // Bias samples toward the originating edge so tall crests read clearly.
        final xNorm = fromLeft
            ? (u * u * 0.55 + u * 0.45)
            : (1.0 - (u * u * 0.55 + u * 0.45));
        final x = xNorm * w;

        final tall = edgeTallness(xNorm);
        final travel = travelPulse(xNorm, timeSec * speedBoost, phase * 0.17,
            fromLeft: fromLeft);

        final wave = math.sin(xNorm * freq * math.pi * 2 + t) * 0.55 +
            math.sin(xNorm * freq * 1.7 * math.pi * 2 + t * 1.31 + 1.1) * 0.30 +
            math.sin(xNorm * freq * 0.55 * math.pi * 2 - t * 0.72 + phase) *
                0.22 +
            math.sin(t * 1.9 + xNorm * 4.0 + phase) * 0.12;

        final y = topInset * 0.12 +
            bandH *
                (baseYNorm + wave * (ampPx / bandH) * ampBoost * tall * travel)
                    .clamp(0.06, 0.88);

        // Stronger near edges; still visible as crest crosses mid.
        final side = fromLeft ? (1.0 - xNorm) : xNorm;
        final sideGain = 0.45 + 0.55 * math.pow(side.clamp(0.0, 1.0), 0.65);
        final localPeak = peak * energy * sideGain * (0.7 + 0.3 * travel);
        final r = (w * 0.22 + bandH * 0.42) *
            radiusScale *
            (0.85 + 0.25 * tall) *
            (1.0 + 0.08 * pull);

        haze(Offset(x, y), r, color, localPeak.clamp(0.0, 0.34));
      }
    }

    // Ambient wash under the ribbons (still inside fixed band).
    haze(
      Offset(w * 0.5, topInset + bandH * 0.28),
      math.max(w * 0.55, bandH * 0.9),
      primary,
      0.10 * energy,
    );
    haze(
      Offset(w * 0.22, topInset + bandH * 0.22),
      w * 0.42,
      cyan,
      0.08 * energy,
    );
    haze(
      Offset(w * 0.78, topInset + bandH * 0.20),
      w * 0.40,
      violet,
      0.08 * energy,
    );

    // Left-edge ribbons → center
    paintRibbon(
      fromLeft: true,
      color: cyan,
      baseYNorm: 0.32,
      ampPx: 38,
      freq: 1.15,
      phase: 0.2,
      speed: 0.55,
      peak: 0.22,
      radiusScale: 0.95,
    );
    paintRibbon(
      fromLeft: true,
      color: primary,
      baseYNorm: 0.44,
      ampPx: 48,
      freq: 0.85,
      phase: 1.4,
      speed: 0.42,
      peak: 0.20,
      radiusScale: 1.05,
    );
    paintRibbon(
      fromLeft: true,
      color: mint,
      baseYNorm: 0.22,
      ampPx: 30,
      freq: 1.55,
      phase: 2.7,
      speed: 0.72,
      peak: 0.16,
      radiusScale: 0.78,
      samples: 24,
    );

    // Right-edge ribbons → center
    paintRibbon(
      fromLeft: false,
      color: violet,
      baseYNorm: 0.30,
      ampPx: 40,
      freq: 1.05,
      phase: 0.8,
      speed: 0.50,
      peak: 0.22,
      radiusScale: 0.98,
    );
    paintRibbon(
      fromLeft: false,
      color: secondary,
      baseYNorm: 0.46,
      ampPx: 52,
      freq: 0.78,
      phase: 2.1,
      speed: 0.38,
      peak: 0.19,
      radiusScale: 1.08,
    );
    paintRibbon(
      fromLeft: false,
      color: rose,
      baseYNorm: 0.20,
      ampPx: 28,
      freq: 1.65,
      phase: 3.3,
      speed: 0.80,
      peak: 0.15,
      radiusScale: 0.74,
      samples: 24,
    );
    paintRibbon(
      fromLeft: false,
      color: sky,
      baseYNorm: 0.38,
      ampPx: 34,
      freq: 1.25,
      phase: 4.0,
      speed: 0.62,
      peak: 0.14,
      radiusScale: 0.82,
      samples: 22,
    );

    // Crossing mid crests — taller fronts that have left the edges.
    paintRibbon(
      fromLeft: true,
      color: Color.lerp(cyan, violet, 0.4)!,
      baseYNorm: 0.36,
      ampPx: 44,
      freq: 0.95,
      phase: 5.2,
      speed: 0.48,
      peak: 0.14,
      radiusScale: 0.88,
      samples: 26,
    );
    paintRibbon(
      fromLeft: false,
      color: Color.lerp(mint, rose, 0.35)!,
      baseYNorm: 0.34,
      ampPx: 42,
      freq: 1.05,
      phase: 5.9,
      speed: 0.52,
      peak: 0.13,
      radiusScale: 0.86,
      samples: 26,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EdgeWaveAuroraPainter oldDelegate) {
    return oldDelegate.timeSec != timeSec ||
        oldDelegate.pull != pull ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.baseIntensity != baseIntensity ||
        oldDelegate.topInset != topInset;
  }
}
