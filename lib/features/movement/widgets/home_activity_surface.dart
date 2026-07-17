import 'dart:math' as math;

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
  final Color glowPrimary;
  final Color glowSecondary;
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

  /// Near-white middle cards (no wallet tint).
  static const HomeActivitySurfaceStyle middleWhite = HomeActivitySurfaceStyle(
    cardTop: Color(0xFFFFFFFF),
    cardBottom: Color(0xFFF7F7F9),
    border: Color(0xFFE0E0E6),
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
    glowSecondary: Color(0xFFF0F0F4),
    glowTertiary: Color(0xFFE4E4EA),
  );

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
          glowPrimary: Color(0xFFFFF3D6),
          glowSecondary: Color(0xFFFFD080),
          glowTertiary: Color(0xFFFF9A2E),
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
          glowPrimary: Color(0xFFF0F9FF),
          glowSecondary: Color(0xFFA8D4F5),
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
      _ => middleWhite,
    };
  }
}

/// Where a row sits in the list — drives white middle vs glowing ends.
enum HomeActivityListBand { top, middle, bottom }

HomeActivityListBand homeActivityListBand(int index, int total) {
  if (total <= 0) return HomeActivityListBand.middle;
  if (total == 1) return HomeActivityListBand.top;
  if (total == 2) {
    return index == 0
        ? HomeActivityListBand.top
        : HomeActivityListBand.bottom;
  }
  if (total == 3) {
    if (index == 0) return HomeActivityListBand.top;
    if (index == 2) return HomeActivityListBand.bottom;
    return HomeActivityListBand.middle;
  }
  final t = index / (total - 1);
  if (t <= 0.30) return HomeActivityListBand.top;
  if (t >= 0.70) return HomeActivityListBand.bottom;
  return HomeActivityListBand.middle;
}

/// Moving glow **inside** top/bottom cards only (clipped by the card).
class HomeActivityCardGlow extends StatelessWidget {
  final HomeActivitySurfaceStyle style;
  final Animation<double> phase;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        if (reduce) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.45),
                radius: 1.05,
                colors: [
                  style.glowPrimary.withValues(alpha: 0.4),
                  style.glowSecondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: phase,
          builder: (context, _) {
            final t = phase.value * 2 * math.pi;
            final s = (seed & 0x7fffffff) / 0x7fffffff;
            final s2 =
                ((seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

            Widget orb({
              required double ax,
              required double ay,
              required double sizeFactor,
              required Color color,
              required double peakAlpha,
              required double phaseOff,
              required double speed,
            }) {
              // Continuous loop — sin/cos never jumps.
              final px = (ax + 0.22 * math.sin(t * speed + phaseOff))
                  .clamp(-0.9, 0.9);
              final py = (ay + 0.18 * math.cos(t * speed * 0.85 + phaseOff * 1.1))
                  .clamp(-0.9, 0.9);
              final pulse = 0.5 +
                  0.5 * (0.5 + 0.5 * math.sin(t * speed * 1.1 + phaseOff));
              final reach = 0.78 +
                  0.32 * (0.5 + 0.5 * math.cos(t * speed * 0.7 + phaseOff));
              final dim = math.min(w, h) * sizeFactor * reach;

              return Align(
                alignment: Alignment(px, py),
                child: Container(
                  width: dim,
                  height: dim,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: peakAlpha * pulse),
                        color.withValues(alpha: peakAlpha * pulse * 0.35),
                        color.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.38, 1.0],
                    ),
                  ),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        -0.25 + 0.1 * math.sin(t + s * 3),
                        -0.5 + 0.08 * math.cos(t * 0.8),
                      ),
                      radius: 1.2,
                      colors: [
                        style.glowPrimary.withValues(alpha: 0.38),
                        style.glowSecondary.withValues(alpha: 0.12),
                        style.glowTertiary.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                orb(
                  ax: -0.4 + 0.15 * s,
                  ay: -0.35 + 0.1 * s2,
                  sizeFactor: 1.05,
                  color: style.glowPrimary,
                  peakAlpha: 0.62,
                  phaseOff: s * 6.28,
                  speed: 1.0,
                ),
                orb(
                  ax: 0.5 + 0.1 * s2,
                  ay: 0.15 + 0.15 * s,
                  sizeFactor: 0.85,
                  color: style.glowSecondary,
                  peakAlpha: 0.48,
                  phaseOff: s2 * 6.28 + 2.0,
                  speed: 1.15,
                ),
                orb(
                  ax: 0.1 + 0.12 * s,
                  ay: 0.55 + 0.1 * s2,
                  sizeFactor: 0.65,
                  color: style.glowTertiary,
                  peakAlpha: 0.34,
                  phaseOff: (s + s2) * 3.14 + 1.1,
                  speed: 0.9,
                ),
              ],
            );
          },
        );
      },
    );
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
