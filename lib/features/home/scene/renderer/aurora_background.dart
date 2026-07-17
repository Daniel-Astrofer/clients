import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';

/// Soft multi-blob aurora for the home shell (theater background glow).
///
/// **Look:** full rich multi-blob haze (designed theater light).
/// **Freeze-safe:**
/// - No AnimationController.repeat
/// - No per-frame re-bake of radials (that froze the UI)
/// - Picture built at most once per palette+size change, never inside a tick
/// - Palette apply is post-frame only (never setState/notify during build)
class SceneAuroraBackground extends ConsumerStatefulWidget {
  const SceneAuroraBackground({super.key});

  @override
  ConsumerState<SceneAuroraBackground> createState() =>
      _SceneAuroraBackgroundState();
}

class _SceneAuroraBackgroundState extends ConsumerState<SceneAuroraBackground> {
  Color _primary = const Color(0xFF4D7EFF);
  Color _secondary = const Color(0xFF9B7BFF);
  double _intensity = 0.36;
  double _topInset = 0;

  Size? _size;
  ui.Picture? _picture;
  int _key = 0;
  int _builtKey = -1;
  bool _applyScheduled = false;

  // Desired palette from last build (applied post-frame).
  Color? _wantPrimary;
  Color? _wantSecondary;
  double? _wantIntensity;
  double? _wantTopInset;

  @override
  void dispose() {
    _picture?.dispose();
    super.dispose();
  }

  bool _nearColor(Color a, Color b) =>
      (a.r - b.r).abs() < 0.02 &&
      (a.g - b.g).abs() < 0.02 &&
      (a.b - b.b).abs() < 0.02 &&
      (a.a - b.a).abs() < 0.02;

  void _scheduleApply({
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
          (_intensity - i).abs() < 0.015 &&
          (_topInset - t).abs() < 0.5) {
        return;
      }
      _primary = p;
      _secondary = s;
      _intensity = i;
      _topInset = t;
      _key++;
      // Drop cached picture so next paint rebuilds once.
      _picture?.dispose();
      _picture = null;
      _builtKey = -1;
      setState(() {});
    });
  }

  ui.Picture _ensurePicture(Size size) {
    if (_size == size && _builtKey == _key && _picture != null) {
      return _picture!;
    }
    _picture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintField(
      canvas,
      size,
      primary: _primary,
      secondary: _secondary,
      intensity: _intensity,
      topInset: _topInset,
    );
    _picture = recorder.endRecording();
    _size = size;
    _builtKey = _key;
    return _picture!;
  }

  @override
  Widget build(BuildContext context) {
    final bg = ref.watch(homeSceneBackgroundProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    if (!bg.isActive || bg.type == SceneBackgroundType.none) {
      return const SizedBox.shrink();
    }

    _scheduleApply(
      primary: bg.primary ?? const Color(0xFF4D7EFF),
      secondary: bg.secondary ?? const Color(0xFF9B7BFF),
      intensity: bg.intensity.clamp(0.28, 0.75),
      topInset: topInset,
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            if (size.isEmpty) return const SizedBox.expand();
            final picture = _ensurePicture(size);
            return CustomPaint(
              painter: _PicturePainter(picture: picture),
              isComplex: true,
              willChange: false,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _PicturePainter extends CustomPainter {
  _PicturePainter({required this.picture});
  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _PicturePainter oldDelegate) =>
      oldDelegate.picture != picture;
}

// ── Rich static field (designed theater glow) ───────────────────────────────

void _paintField(
  Canvas canvas,
  Size size, {
  required Color primary,
  required Color secondary,
  required double intensity,
  required double topInset,
}) {
  final w = size.width;
  final h = size.height;
  final s = (intensity / 0.4).clamp(0.65, 1.55);
  final stops = const [0.0, 0.18, 0.38, 0.58, 0.78, 1.0];
  final colors = List<Color>.filled(6, const Color(0x00000000));

  void haze(Offset c, double r, Color color, double peak) {
    if (r <= 1 || peak <= 0.01) return;
    colors[0] = color.withValues(alpha: peak * 0.55);
    colors[1] = color.withValues(alpha: peak * 0.50);
    colors[2] = color.withValues(alpha: peak * 0.38);
    colors[3] = color.withValues(alpha: peak * 0.18);
    colors[4] = color.withValues(alpha: peak * 0.06);
    colors[5] = color.withValues(alpha: 0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(c, r, colors, stops),
    );
  }

  final cyan = Color.lerp(primary, const Color(0xFF5EC8E8), 0.55)!;
  final sky = Color.lerp(secondary, const Color(0xFF7DD3FC), 0.55)!;
  final mint = Color.lerp(secondary, const Color(0xFF5EEAD4), 0.45)!;

  haze(
    Offset(w * 0.50, h * 0.10 + topInset * 0.04),
    math.max(w, h) * 1.05,
    primary,
    0.22 * s,
  );
  haze(
    Offset(w * 0.55, h * 0.08 + topInset * 0.03),
    math.max(w, h) * 0.95,
    secondary,
    0.16 * s,
  );

  final blobs = <(double, double, double, Color, double)>[
    (0.28, 0.14, 0.95, primary, 0.20),
    (0.74, 0.12, 0.90, secondary, 0.18),
    (0.48, 0.22, 0.88, cyan, 0.14),
    (0.12, 0.24, 0.78, sky, 0.12),
    (0.88, 0.26, 0.72, mint, 0.10),
    (0.52, 0.06, 0.70, primary, 0.13),
  ];

  for (final b in blobs) {
    final cx = b.$1 * w;
    final cy = b.$2 * h * 0.55 + topInset * 0.04;
    final r = w * b.$3;
    final peak = (b.$5 * s).clamp(0.0, 0.32);
    haze(Offset(cx, cy), r, b.$4, peak);
  }
}
