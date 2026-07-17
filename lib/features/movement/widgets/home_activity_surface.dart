import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Home activity card paper + ink for each ledger balance tab.
@immutable
class HomeActivitySurfaceStyle {
  final Color cardTop;
  final Color cardBottom;
  final Color border;
  final Color title;
  final Color subtitle;
  final Color meta;
  final Color amount;
  final Color divider;
  final Color detailLabel;
  final Color detailValue;
  final Color action;
  final bool invertInk;
  /// Primary glow tint (wallet-focused).
  final Color glowPrimary;
  /// Secondary glow tint (highlight / birlhos).
  final Color glowSecondary;
  /// Soft rim / depth tint.
  final Color glowTertiary;

  const HomeActivitySurfaceStyle({
    required this.cardTop,
    required this.cardBottom,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
    required this.divider,
    required this.detailLabel,
    required this.detailValue,
    required this.action,
    required this.invertInk,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.glowTertiary,
  });

  /// [viewName] is `HomeLedgerBalanceView.name`.
  static HomeActivitySurfaceStyle forLedgerViewName(String viewName) {
    return switch (viewName) {
      'onChain' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xFFFFC878),
          cardBottom: Color(0xFFFFA940),
          border: Color(0xFFE08920),
          title: Color(0xFF1A0C02),
          subtitle: Color(0xFF3D2208),
          meta: Color(0xFF5C3410),
          amount: Color(0xFF120800),
          divider: Color(0xCC8A5010),
          detailLabel: Color(0xFF2A1604),
          detailValue: Color(0xFF100600),
          action: Color(0xFF1A0C02),
          invertInk: true,
          glowPrimary: Color(0xFFFFE8B0),
          glowSecondary: Color(0xFFFFCC66),
          glowTertiary: Color(0xFFFF8A1A),
        ),
      'cold' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xFF8EC8F0),
          cardBottom: Color(0xFF5AADD9),
          border: Color(0xFF2E7EB0),
          title: Color(0xFF061018),
          subtitle: Color(0xFF0E2433),
          meta: Color(0xFF163447),
          amount: Color(0xFF040A10),
          divider: Color(0xCC1A4A66),
          detailLabel: Color(0xFF0A1C28),
          detailValue: Color(0xFF040C14),
          action: Color(0xFF061018),
          invertInk: true,
          glowPrimary: Color(0xFFE8F6FF),
          glowSecondary: Color(0xFF9FD0F5),
          glowTertiary: Color(0xFF3D8FCB),
        ),
      'platform' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xFFE8ECF2),
          cardBottom: Color(0xFFD2D8E2),
          border: Color(0xFF9AA3B0),
          title: Color(0xFF0A0A0C),
          subtitle: Color(0xFF2C3038),
          meta: Color(0xFF4A5060),
          amount: Color(0xFF000000),
          divider: Color(0xFFB0B6C0),
          detailLabel: Color(0xFF1C1C1F),
          detailValue: Color(0xFF0A0A0B),
          action: Color(0xFF0A0A0C),
          invertInk: false,
          glowPrimary: Color(0xFFFFFFFF),
          glowSecondary: Color(0xFFD0D8E8),
          glowTertiary: Color(0xFFA8B4C8),
        ),
      _ => const HomeActivitySurfaceStyle(
          // Total — near white paper, soft neutral glow only inside cards.
          cardTop: Color(0xFFFAFAFB),
          cardBottom: Color(0xFFF0F0F3),
          border: Color(0xFFD0D0D6),
          title: Color(0xFF0A0A0C),
          subtitle: Color(0xFF3A3A42),
          meta: Color(0xFF5C5C66),
          amount: Color(0xFF000000),
          divider: Color(0xFFD0D0D4),
          detailLabel: Color(0xFF1C1C1F),
          detailValue: Color(0xFF0A0A0B),
          action: Color(0xFF0A0A0C),
          invertInk: false,
          glowPrimary: Color(0xFFFFFFFF),
          glowSecondary: Color(0xFFE8E8EE),
          glowTertiary: Color(0xFFD0D0D8),
        ),
    };
  }
}

/// Soft moving glow **inside** a transaction card (clipped to the card).
///
/// Not for the black gaps between cards. Motion is seamless (sin/cos).
/// Intensity, radius and position vary gently; colors follow [style].
class HomeActivityCardGlow extends StatelessWidget {
  final HomeActivitySurfaceStyle style;
  final Animation<double> phase;
  /// Per-card seed so each popup drifts differently.
  final int seed;

  const HomeActivityCardGlow({
    super.key,
    required this.style,
    required this.phase,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;
    if (reduce) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: phase,
        builder: (context, _) {
          return CustomPaint(
            painter: _InteriorCardGlowPainter(
              phase: phase.value,
              seed: seed,
              primary: style.glowPrimary,
              secondary: style.glowSecondary,
              tertiary: style.glowTertiary,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _InteriorCardGlowPainter extends CustomPainter {
  final double phase;
  final int seed;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  _InteriorCardGlowPainter({
    required this.phase,
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = phase * 2 * math.pi;
    // Stable offsets from seed so cards don't all move in sync.
    final s = (seed & 0x7fffffff) / 0x7fffffff;
    final s2 = ((seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
    final s3 = ((seed * 1664525 + 1013904223) & 0x7fffffff) / 0x7fffffff;

    void glow({
      required double nx,
      required double ny,
      required double baseR,
      required Color color,
      required double baseAlpha,
      required double phaseOffset,
      required double breathe,
    }) {
      // Seamless motion — no linear sweep that jumps on loop.
      final driftX = 0.08 * math.sin(t + phaseOffset);
      final driftY = 0.07 * math.cos(t * 0.85 + phaseOffset * 1.3);
      final pulse = 0.55 +
          0.45 * (0.5 + 0.5 * math.sin(t * breathe + phaseOffset));
      final reach = 0.75 +
          0.35 * (0.5 + 0.5 * math.cos(t * (breathe * 0.7) + phaseOffset));
      final cx = size.width * (nx + driftX).clamp(0.08, 0.92);
      final cy = size.height * (ny + driftY).clamp(0.08, 0.92);
      final r = (math.min(size.width, size.height) * baseR * reach)
          .clamp(12.0, math.min(size.width, size.height) * 0.55);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          r,
          [
            color.withValues(alpha: baseAlpha * pulse),
            color.withValues(alpha: baseAlpha * pulse * 0.35),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.42, 1.0],
        );
      canvas.drawRect(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        paint,
      );
    }

    // Variable intensity / reach / color — soft interior only.
    glow(
      nx: 0.22 + 0.12 * s,
      ny: 0.30 + 0.10 * s2,
      baseR: 0.42,
      color: primary,
      baseAlpha: 0.22,
      phaseOffset: s * 6.28,
      breathe: 1.0,
    );
    glow(
      nx: 0.72 + 0.08 * s2,
      ny: 0.55 + 0.12 * s3,
      baseR: 0.34,
      color: secondary,
      baseAlpha: 0.16,
      phaseOffset: s2 * 6.28 + 1.7,
      breathe: 1.25,
    );
    glow(
      nx: 0.48 + 0.10 * s3,
      ny: 0.18 + 0.08 * s,
      baseR: 0.28,
      color: tertiary,
      baseAlpha: 0.11,
      phaseOffset: s3 * 6.28 + 3.1,
      breathe: 0.85,
    );
  }

  @override
  bool shouldRepaint(covariant _InteriorCardGlowPainter oldDelegate) {
    return (phase - oldDelegate.phase).abs() > 0.002 ||
        seed != oldDelegate.seed ||
        primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        tertiary != oldDelegate.tertiary;
  }
}

/// Shared circular reveal used by notifications and transaction detail.
Route<T> keroseneCircularRevealRoute<T>({
  required Widget page,
  required Rect originRect,
  Duration? transitionDuration,
  Duration? reverseTransitionDuration,
}) {
  return PageRouteBuilder<T>(
    opaque: true,
    transitionDuration:
        transitionDuration ?? const Duration(milliseconds: 420),
    reverseTransitionDuration:
        reverseTransitionDuration ?? const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true ||
          MediaQuery.maybeOf(context)?.accessibleNavigation == true;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (reduce) {
        return FadeTransition(opacity: curved, child: child);
      }
      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final center = originRect.center;
          final startRadius =
              math.max(originRect.width, originRect.height) / 2;
          final endRadius = [
            Offset.zero,
            Offset(size.width, 0),
            Offset(0, size.height),
            Offset(size.width, size.height),
          ].map((c) => (c - center).distance).reduce(math.max);
          final radius =
              startRadius + (endRadius - startRadius) * curved.value;
          final opacity = const Interval(
            0.10,
            0.78,
            curve: Curves.easeOutCubic,
          ).transform(curved.value);
          return ClipPath(
            clipper: _KeroCircularRevealClipper(
              center: center,
              radius: radius,
            ),
            child: Opacity(opacity: opacity, child: child),
          );
        },
      );
    },
  );
}

Rect? keroseneOriginRectFromContext(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay?.context.findRenderObject();
  final overlayBox = overlay is RenderBox ? overlay : null;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  return topLeft & box.size;
}

class _KeroCircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _KeroCircularRevealClipper({
    required this.center,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_KeroCircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
