import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';

/// Soft multi-blob aurora for the home shell (theater background glow).
///
/// **Look:** full rich multi-blob haze + soft stops — the designed theater light.
/// **Perf:** no continuous ambient ticker. Field is cached as a [ui.Picture]
/// and only re-baked when size or palette changes (theater color swap).
class SceneAuroraBackground extends ConsumerStatefulWidget {
  const SceneAuroraBackground({super.key});

  @override
  ConsumerState<SceneAuroraBackground> createState() =>
      _SceneAuroraBackgroundState();
}

class _SceneAuroraBackgroundState extends ConsumerState<SceneAuroraBackground>
    with SingleTickerProviderStateMixin {
  static const _colorDuration = Duration(milliseconds: 720);

  late final AnimationController _colorCtrl;
  late final _AuroraPalette _palette;

  Color _fromPrimary = const Color(0xFF4D7EFF);
  Color _fromSecondary = const Color(0xFF9B7BFF);
  double _fromIntensity = 0.36;
  Color _toPrimary = const Color(0xFF4D7EFF);
  Color _toSecondary = const Color(0xFF9B7BFF);
  double _toIntensity = 0.36;
  bool _seeded = false;

  Size? _lastSize;
  ui.Picture? _picture;
  int _pictureGen = 0;
  int _builtGen = -1;

  @override
  void initState() {
    super.initState();
    _palette = _AuroraPalette();
    _colorCtrl = AnimationController(vsync: this, duration: _colorDuration)
      ..addListener(_onColorTick)
      ..value = 1;
  }

  @override
  void dispose() {
    _colorCtrl.dispose();
    _picture?.dispose();
    _palette.dispose();
    super.dispose();
  }

  void _onColorTick() {
    final t = Curves.easeInOutCubic.transform(_colorCtrl.value);
    _palette.primary = Color.lerp(_fromPrimary, _toPrimary, t) ?? _toPrimary;
    _palette.secondary =
        Color.lerp(_fromSecondary, _toSecondary, t) ?? _toSecondary;
    _palette.intensity = _fromIntensity + (_toIntensity - _fromIntensity) * t;
    _pictureGen++;
    _palette.notify();
  }

  void _beginColorTransition({
    required Color primary,
    required Color secondary,
    required double intensity,
    required bool reduce,
  }) {
    if (!_seeded) {
      _fromPrimary = primary;
      _fromSecondary = secondary;
      _fromIntensity = intensity;
      _toPrimary = primary;
      _toSecondary = secondary;
      _toIntensity = intensity;
      _seeded = true;
      _colorCtrl.value = 1;
      _onColorTick();
      return;
    }
    if (_near(_toPrimary, primary) &&
        _near(_toSecondary, secondary) &&
        (_toIntensity - intensity).abs() < 0.015) {
      return;
    }
    final t = Curves.easeInOutCubic.transform(_colorCtrl.value);
    _fromPrimary = Color.lerp(_fromPrimary, _toPrimary, t) ?? _toPrimary;
    _fromSecondary =
        Color.lerp(_fromSecondary, _toSecondary, t) ?? _toSecondary;
    _fromIntensity = _fromIntensity + (_toIntensity - _fromIntensity) * t;
    _toPrimary = primary;
    _toSecondary = secondary;
    _toIntensity = intensity;
    if (reduce) {
      _colorCtrl.value = 1;
      _onColorTick();
    } else {
      _colorCtrl.forward(from: 0);
    }
  }

  bool _near(Color a, Color b) =>
      (a.r - b.r).abs() < 0.02 &&
      (a.g - b.g).abs() < 0.02 &&
      (a.b - b.b).abs() < 0.02 &&
      (a.a - b.a).abs() < 0.02;

  ui.Picture _buildPicture(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintField(
      canvas,
      size,
      primary: _palette.primary,
      secondary: _palette.secondary,
      intensity: _palette.intensity,
      topInset: _palette.topInset,
    );
    return recorder.endRecording();
  }

  @override
  Widget build(BuildContext context) {
    final bg = ref.watch(homeSceneBackgroundProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final reduce = MediaQuery.disableAnimationsOf(context);

    if (!bg.isActive || bg.type == SceneBackgroundType.none) {
      return const SizedBox.shrink();
    }

    _palette.topInset = topInset;
    _beginColorTransition(
      primary: bg.primary ?? const Color(0xFF4D7EFF),
      secondary: bg.secondary ?? const Color(0xFF9B7BFF),
      intensity: bg.intensity.clamp(0.28, 0.75),
      reduce: reduce,
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CachedAuroraPainter(
            palette: _palette,
            ensurePicture: (size) {
              if (_lastSize != size ||
                  _builtGen != _pictureGen ||
                  _picture == null) {
                _picture?.dispose();
                _picture = _buildPicture(size);
                _lastSize = size;
                _builtGen = _pictureGen;
              }
              return _picture!;
            },
          ),
          isComplex: true,
          willChange: false,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AuroraPalette extends ChangeNotifier {
  Color primary = const Color(0xFF4D7EFF);
  Color secondary = const Color(0xFF9B7BFF);
  double intensity = 0.36;
  double topInset = 0;

  void notify() => notifyListeners();
}

class _CachedAuroraPainter extends CustomPainter {
  _CachedAuroraPainter({
    required this.palette,
    required this.ensurePicture,
  }) : super(repaint: palette);

  final _AuroraPalette palette;
  final ui.Picture Function(Size size) ensurePicture;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(ensurePicture(size));
  }

  @override
  bool shouldRepaint(covariant _CachedAuroraPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

// ── Rich static field (designed theater glow — multi-blob soft haze) ────────

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

  // Ambient washes (large soft discs)
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

  // Soft multi-blob field — designed composition for the theater stage
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
