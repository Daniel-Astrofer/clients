import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_stage_playback_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';

/// Design-system color tokens for theater glows.
/// Never resolve to pure white for washes — always a tinted color.
Color resolveStageColorToken(String token, {Color? fallback}) {
  return switch (token.trim().toLowerCase()) {
    'positive' || 'green' || 'up' => homePositiveColor,
    'danger' || 'red' || 'down' => AppColors.hexFFFF5A67,
    'amber' || 'onchain' || 'orange' || 'bitcoin' => homeAmberColor,
    'cold' || 'blue' || 'sky' => const Color(0xFF7DD3FC),
    'platform' || 'white' => const Color(0xFFB8C4D4),
    'muted' => homeMutedTextColor,
    'brand' || 'warm' => const Color(0xFFE8D5B5),
    'soft' || 'cream' => const Color(0xFFF2E6D0),
    _ => fallback ?? const Color(0xFF7DD3FC),
  };
}

/// Colored accent for resting wash by ledger page — never pure white.
Color restingWashAccentFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => const Color(0xFF7DD3FC),
    HomeLedgerBalanceView.platform => const Color(0xFFB8C4D4),
    HomeLedgerBalanceView.onChain => homeAmberColor,
    HomeLedgerBalanceView.cold => const Color(0xFF7DD3FC),
  };
}

String restingWashTokenFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => 'cold',
    HomeLedgerBalanceView.platform => 'platform',
    HomeLedgerBalanceView.onChain => 'amber',
    HomeLedgerBalanceView.cold => 'cold',
  };
}

@immutable
class TheaterTopWashStyle {
  final Color accent;
  final double peakAlpha;
  final Duration transition;
  final bool theaterActive;

  const TheaterTopWashStyle({
    required this.accent,
    required this.peakAlpha,
    required this.theaterActive,
    this.transition = const Duration(milliseconds: 480),
  });

  Color get solidColor => Color.alphaBlend(
        accent.withValues(alpha: peakAlpha.clamp(0.0, 0.72)),
        const Color(0xFF000000),
      );
}

TheaterTopWashStyle resolveTheaterTopWashStyle({
  required HomeStage stage,
  required HomeLedgerBalanceView view,
  required bool stagePlaying,
}) {
  final atmo = stage.resolvedAtmosphere;
  final theaterActive = stagePlaying && stage.isActive;
  final ms = atmo.transitionMs.clamp(180, 1200);

  if (theaterActive && atmo.hasGlows) {
    final main = atmo.glows.first;
    var accent = resolveStageColorToken(main.colorToken);
    if (accent.computeLuminance() > 0.92 && accent.a >= 0.95) {
      accent = const Color(0xFF7DD3FC);
    }
    return TheaterTopWashStyle(
      accent: accent,
      peakAlpha: main.intensity.clamp(0.38, 0.58),
      theaterActive: true,
      transition: Duration(milliseconds: ms),
    );
  }

  if (theaterActive) {
    return TheaterTopWashStyle(
      accent: restingWashAccentFor(view),
      peakAlpha: 0.48,
      theaterActive: true,
      transition: Duration(milliseconds: ms),
    );
  }

  return TheaterTopWashStyle(
    accent: restingWashAccentFor(view),
    peakAlpha: 0.22,
    theaterActive: false,
    transition: Duration(milliseconds: ms),
  );
}

TheaterTopWashStyle watchTheaterTopWashStyle(WidgetRef ref) {
  final stage = ref.watch(homeSurfaceProvider.select((s) => s.stage));
  final playback = ref.watch(homeStagePlaybackProvider);
  final view = ref.watch(homeLedgerBalanceViewProvider);
  return resolveTheaterTopWashStyle(
    stage: stage,
    view: view,
    stagePlaying: playback.isPlaying && stage.isActive,
  );
}

/// Scaffold stays pure black — glow lives only in the header wash (no hard
/// solid slab behind the scroll view that reads as a cut band).
final theaterScaffoldSolidColorProvider = Provider<Color>((ref) {
  return homeBackgroundColor;
});

/// Wash around the communication stage (greeting / theater).
///
/// Revolut-style soft radial bloom. Layout height includes a **fade tail** so
/// the soft edge is inside the sliver paint bounds (CustomScrollView clips
/// children to their layout size — without the tail, blur is hard-cut).
class HomeTheaterHeaderWash extends ConsumerWidget {
  final Widget child;

  const HomeTheaterHeaderWash({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = watchTheaterTopWashStyle(ref);
    final stage = ref.watch(homeSurfaceProvider.select((s) => s.stage));
    final view = ref.watch(homeLedgerBalanceViewProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;

    // Extra layout height so ImageFilter + radial falloff can die to alpha 0
    // *inside* the painted box (avoids the hard rectangular cut in the shot).
    final fadeTail = style.theaterActive
        ? (screenH * 0.07).clamp(40.0, 72.0)
        : (screenH * 0.12).clamp(72.0, 120.0);

    final atmo = stage.resolvedAtmosphere;
    final backendGlows = atmo.hasGlows && style.theaterActive
        ? atmo.glows
        : const <HomeStageGlow>[];

    return Stack(
      // Clip after soft mask reaches 0 — no visible hard edge.
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _SoftEdgeBloom(
              theaterActive: style.theaterActive,
              child: _RevolutAmbientBloom(
                accent: style.accent,
                peakAlpha: style.peakAlpha,
                theaterActive: style.theaterActive,
              ),
            ),
          ),
        ),
        if (backendGlows.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: _SoftEdgeBloom(
                theaterActive: true,
                child: _TheaterSoftGlows(
                  glows: backendGlows,
                  intensityScale: 0.85,
                ),
              ),
            ),
          )
        else if (style.theaterActive)
          Positioned.fill(
            child: IgnorePointer(
              child: _SoftEdgeBloom(
                theaterActive: true,
                child: _TheaterSoftGlows(
                  glows: [
                    HomeStageGlow(
                      id: 'fallback',
                      colorToken: restingWashTokenFor(view),
                      x: 0.5,
                      y: 0.05,
                      width: 1.5,
                      height: 0.7,
                      intensity: 0.30,
                      radius: 0.7,
                    ),
                  ],
                  intensityScale: 1.0,
                ),
              ),
            ),
          ),
        // Content + fade tail define layout height for the sliver.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: child,
            ),
            SizedBox(height: fadeTail),
          ],
        ),
      ],
    );
  }
}

/// Multiplies child alpha with a soft vertical mask so the bottom of the
/// paint box is fully transparent (no hard seam against black below).
class _SoftEdgeBloom extends StatelessWidget {
  final Widget child;
  final bool theaterActive;

  const _SoftEdgeBloom({
    required this.child,
    required this.theaterActive,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        // Theater: denser upper ~30%, long soft tail.
        // Resting: softer overall, longer feather.
        final stops = theaterActive
            ? const [0.0, 0.28, 0.55, 0.82, 1.0]
            : const [0.0, 0.18, 0.45, 0.75, 1.0];
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0xD9FFFFFF),
            Color(0x55FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: stops,
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// Revolut-like ambient: soft radial cloud + slow breath/drift.
///
/// Animation only transforms a [RepaintBoundary] of static blurred layers.
class _RevolutAmbientBloom extends StatefulWidget {
  final Color accent;
  final double peakAlpha;
  final bool theaterActive;

  const _RevolutAmbientBloom({
    required this.accent,
    required this.peakAlpha,
    required this.theaterActive,
  });

  @override
  State<_RevolutAmbientBloom> createState() => _RevolutAmbientBloomState();
}

class _RevolutAmbientBloomState extends State<_RevolutAmbientBloom>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 10000);

  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: _cycle)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final theaterActive = widget.theaterActive;
        final driftAmp = theaterActive ? 12.0 : 8.0;
        final breathScaleAmp = theaterActive ? 0.035 : 0.028;
        final pulseAmp = theaterActive ? 0.08 : 0.06;

        final layers = RepaintBoundary(
          child: _StaticRevolutLayers(
            key: ValueKey(
              '${widget.accent.toARGB32()}|${widget.theaterActive}|'
              '${widget.peakAlpha.toStringAsFixed(2)}|${w.round()}x${h.round()}',
            ),
            width: w,
            height: h,
            accent: widget.accent,
            peakAlpha: widget.peakAlpha,
            theaterActive: theaterActive,
          ),
        );

        return AnimatedBuilder(
          animation: _breath,
          child: layers,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_breath.value);
            final pulse = (1.0 - pulseAmp + pulseAmp * 2 * t).clamp(0.85, 1.0);
            final scale = 1.0 - breathScaleAmp + breathScaleAmp * 2 * t;
            final driftX = (t - 0.5) * 2 * driftAmp;
            final driftY = (0.5 - t) * driftAmp * 0.35;

            return Opacity(
              opacity: pulse,
              child: Transform.translate(
                offset: Offset(driftX * 0.3, driftY),
                filterQuality: FilterQuality.low,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.low,
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Frozen blurred cloud layers (ImageFilter stays off the animation tick).
class _StaticRevolutLayers extends StatelessWidget {
  final double width;
  final double height;
  final Color accent;
  final double peakAlpha;
  final bool theaterActive;

  const _StaticRevolutLayers({
    super.key,
    required this.width,
    required this.height,
    required this.accent,
    required this.peakAlpha,
    required this.theaterActive,
  });

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;

    final coreAlpha = theaterActive
        ? peakAlpha.clamp(0.36, 0.58)
        : peakAlpha.clamp(0.12, 0.26);
    final midAlpha = theaterActive ? coreAlpha * 0.42 : coreAlpha * 0.38;
    final outerAlpha = theaterActive ? coreAlpha * 0.12 : coreAlpha * 0.10;

    // Blobs oversized vs band so radial falloff (not the widget edge) is what
    // you see. SoftEdgeBloom handles the final bottom feather.
    final blobW = w * 2.1;
    final blobH = h * (theaterActive ? 1.65 : 1.75);
    final centerY = h * (theaterActive ? 0.06 : 0.0);

    Widget blob({
      required double bw,
      required double bh,
      required double cy,
      required double a0,
      required double a1,
      required double a2,
      required double blur,
      double dx = 0,
      Alignment geometryCenter = const Alignment(0, -0.2),
      double radius = 0.95,
    }) {
      return Positioned(
        left: (w - bw) / 2 + dx,
        top: cy - bh * 0.38,
        width: bw,
        height: bh,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur * 1.2,
            // clamp: blur samples edge color instead of hard transparent cut
            tileMode: TileMode.clamp,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: geometryCenter,
                radius: radius,
                colors: [
                  accent.withValues(alpha: a0),
                  accent.withValues(alpha: a1),
                  accent.withValues(alpha: a2),
                  accent.withValues(alpha: 0),
                ],
                stops: theaterActive
                    ? const [0.0, 0.22, 0.52, 1.0]
                    : const [0.0, 0.28, 0.58, 1.0],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      // Allow blur to paint full rect; outer SoftEdgeBloom + parent clip soft-end.
      clipBehavior: Clip.none,
      children: [
        blob(
          bw: blobW * 1.1,
          bh: blobH * 1.15,
          cy: centerY + h * 0.05,
          a0: outerAlpha * 1.3,
          a1: outerAlpha * 0.75,
          a2: outerAlpha * 0.25,
          blur: 52,
          geometryCenter: const Alignment(0, -0.4),
          radius: 1.05,
        ),
        blob(
          bw: blobW,
          bh: blobH,
          cy: centerY,
          a0: coreAlpha,
          a1: midAlpha,
          a2: outerAlpha,
          blur: 40,
          geometryCenter: const Alignment(0, -0.3),
        ),
        if (theaterActive)
          blob(
            bw: w * 1.45,
            bh: h * 0.95,
            cy: h * 0.0,
            a0: (coreAlpha * 1.1).clamp(0.0, 0.68),
            a1: coreAlpha * 0.5,
            a2: coreAlpha * 0.1,
            blur: 30,
            geometryCenter: const Alignment(0, -0.6),
            radius: 0.88,
          ),
        blob(
          bw: w * 1.15,
          bh: h * 0.85,
          cy: centerY + h * 0.08,
          a0: outerAlpha * 0.95,
          a1: outerAlpha * 0.4,
          a2: 0,
          blur: 48,
          dx: -w * 0.06,
          geometryCenter: const Alignment(-0.4, -0.15),
        ),
        blob(
          bw: w * 1.1,
          bh: h * 0.8,
          cy: centerY + h * 0.1,
          a0: outerAlpha * 0.8,
          a1: outerAlpha * 0.32,
          a2: 0,
          blur: 48,
          dx: w * 0.07,
          geometryCenter: const Alignment(0.42, -0.05),
        ),
      ],
    );
  }
}

/// Soft blurred ovals for backend glows — organic satellites.
class _TheaterSoftGlows extends StatelessWidget {
  final List<HomeStageGlow> glows;
  final double intensityScale;

  const _TheaterSoftGlows({
    required this.glows,
    required this.intensityScale,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final glow in glows)
              Builder(
                builder: (context) {
                  final color = resolveStageColorToken(glow.colorToken);
                  final nx = glow.x.clamp(0.0, 1.0);
                  final ny =
                      (glow.y.clamp(0.0, 1.0) * 0.3).clamp(0.0, 0.3);
                  final bw = (glow.width.clamp(0.5, 2.4)) * w * 1.05;
                  final bh = (glow.height.clamp(0.35, 1.5)) * h * 1.15;
                  final cx = nx * w;
                  final cy = ny * h;
                  final alpha =
                      (glow.intensity * intensityScale).clamp(0.12, 0.45);

                  return Positioned(
                    left: cx - bw / 2,
                    top: cy - bh / 2,
                    width: bw,
                    height: bh,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: (bw * 0.3).clamp(26.0, 58.0),
                        sigmaY: (bh * 0.36).clamp(30.0, 66.0),
                        tileMode: TileMode.clamp,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: alpha),
                              color.withValues(alpha: alpha * 0.4),
                              color.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.42, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
