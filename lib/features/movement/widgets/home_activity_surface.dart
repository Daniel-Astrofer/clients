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

  /// Fully opaque paper — never transparent (avoids black list showing through).
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
          glowPrimary: Color(0xFFFFF8E8),
          glowSecondary: Color(0xFFFFD078),
          glowTertiary: Color(0xFFFFA020),
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
          glowPrimary: Color(0xFFF5FBFF),
          glowSecondary: Color(0xFFA8D8F8),
          glowTertiary: Color(0xFF4A9AD4),
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
          glowSecondary: Color(0xFFD8DEE8),
          glowTertiary: Color(0xFFB0BAC8),
        ),
      _ => const HomeActivitySurfaceStyle(
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
          glowSecondary: Color(0xFFECECF2),
          glowTertiary: Color(0xFFD0D0DA),
        ),
    };
  }
}

/// Moving light **on top of the card paper**, clipped by the card itself.
///
/// Must only be used as a child of a [Container] with opaque [BoxDecoration]
/// and `clipBehavior: Clip.antiAlias`. Never place this on the list background.
class HomeActivityCardGlow extends StatelessWidget {
  final HomeActivitySurfaceStyle style;
  final Animation<double> phase;

  const HomeActivityCardGlow({
    super.key,
    required this.style,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }

        if (reduce) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.25),
                radius: 1.0,
                colors: [
                  style.glowPrimary.withValues(alpha: 0.5),
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
            // Seamless drift — same phase for every card = one shared light path.
            final ax = 0.42 * math.sin(t);
            final ay = -0.2 + 0.32 * math.cos(t * 0.88);
            final pulse =
                0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * 1.05));
            final reach =
                0.85 + 0.25 * (0.5 + 0.5 * math.cos(t * 0.7));
            final dim = math.min(w, h) * 1.2 * reach;

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // Ambient depth on the paper.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(ax * 0.4, ay * 0.5 - 0.15),
                      radius: 1.15,
                      colors: [
                        style.glowPrimary.withValues(alpha: 0.4 * pulse),
                        style.glowSecondary.withValues(alpha: 0.12 * pulse),
                        const Color(0x00000000),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Moving highlight — fully inside the card bounds via parent clip.
                Align(
                  alignment: Alignment(ax, ay),
                  child: OverflowBox(
                    maxWidth: dim,
                    maxHeight: dim,
                    child: Container(
                      width: dim,
                      height: dim,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            style.glowPrimary.withValues(alpha: 0.7 * pulse),
                            style.glowSecondary.withValues(alpha: 0.35 * pulse),
                            const Color(0x00000000),
                          ],
                          stops: const [0.0, 0.38, 1.0],
                        ),
                      ),
                    ),
                  ),
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
