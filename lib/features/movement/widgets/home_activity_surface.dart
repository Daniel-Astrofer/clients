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

  /// Plain white cards — list uses a single shared glow behind them.
  static const HomeActivitySurfaceStyle listCard = HomeActivitySurfaceStyle(
    cardTop: Color(0xF2FFFFFF),
    cardBottom: Color(0xE6F4F4F7),
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

  /// [viewName] is `HomeLedgerBalanceView.name` — drives the **shared** list glow.
  static HomeActivitySurfaceStyle forLedgerViewName(String viewName) {
    return switch (viewName) {
      'onChain' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xF2FFFFFF),
          cardBottom: Color(0xE6FFF6EB),
          border: Color(0xFFE8C99A),
          title: Color(0xFF1A0C02),
          subtitle: Color(0xFF3D2208),
          meta: Color(0xFF5C3410),
          amount: Color(0xFF120800),
          divider: Color(0xCC8A5010),
          detailLabel: Color(0xFF2A1604),
          detailValue: Color(0xFF100600),
          action: Color(0xFF1A0C02),
          invertInk: true,
          glowPrimary: Color(0xFFFFF0C8),
          glowSecondary: Color(0xFFFFB84A),
          glowTertiary: Color(0xFFFF8A1A),
        ),
      'cold' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xF2FFFFFF),
          cardBottom: Color(0xE6EAF5FC),
          border: Color(0xFF9BC4E0),
          title: Color(0xFF061018),
          subtitle: Color(0xFF0E2433),
          meta: Color(0xFF163447),
          amount: Color(0xFF040A10),
          divider: Color(0xCC1A4A66),
          detailLabel: Color(0xFF0A1C28),
          detailValue: Color(0xFF040C14),
          action: Color(0xFF061018),
          invertInk: true,
          glowPrimary: Color(0xFFEAF7FF),
          glowSecondary: Color(0xFF6BB8E8),
          glowTertiary: Color(0xFF2E7EB0),
        ),
      'platform' => const HomeActivitySurfaceStyle(
          cardTop: Color(0xF2FFFFFF),
          cardBottom: Color(0xE6EEF1F5),
          border: Color(0xFFB0B8C4),
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
          glowSecondary: Color(0xFFC8D0DC),
          glowTertiary: Color(0xFF8A96A8),
        ),
      _ => listCard.copyWithGlows(
          glowPrimary: const Color(0xFFFFFFFF),
          glowSecondary: const Color(0xFFE8E8F0),
          glowTertiary: const Color(0xFFC8C8D4),
        ),
    };
  }

  HomeActivitySurfaceStyle copyWithGlows({
    required Color glowPrimary,
    required Color glowSecondary,
    required Color glowTertiary,
  }) {
    return HomeActivitySurfaceStyle(
      cardTop: cardTop,
      cardBottom: cardBottom,
      border: border,
      title: title,
      subtitle: subtitle,
      meta: meta,
      amount: amount,
      divider: divider,
      detailLabel: detailLabel,
      detailValue: detailValue,
      action: action,
      invertInk: invertInk,
      glowPrimary: glowPrimary,
      glowSecondary: glowSecondary,
      glowTertiary: glowTertiary,
    );
  }
}

/// **One** soft glow for the whole transaction list — not per card.
///
/// Sits behind the cards, clipped to the list. Drifts in the middle band with
/// seamless sin/cos motion; intensity and reach breathe gently. Wallet-focused
/// colors come from [style].
class HomeActivityListGlow extends StatelessWidget {
  final HomeActivitySurfaceStyle style;
  final Animation<double> phase;
  final Widget child;

  const HomeActivityListGlow({
    super.key,
    required this.style,
    required this.phase,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Single shared glow layer (behind cards).
          Positioned.fill(
            child: IgnorePointer(
              child: reduce
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            style.glowSecondary.withValues(alpha: 0.35),
                            style.glowTertiary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: phase,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SingleListGlowPainter(
                            phase: phase.value,
                            primary: style.glowPrimary,
                            secondary: style.glowSecondary,
                            tertiary: style.glowTertiary,
                          ),
                        );
                      },
                    ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// One glow blob that drifts smoothly in the list (seamless loop).
class _SingleListGlowPainter extends CustomPainter {
  final double phase;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  _SingleListGlowPainter({
    required this.phase,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = phase * 2 * math.pi;

    // Center path: stays mostly in the middle band, slow drift.
    // sin/cos → when phase wraps 0↔1 the position is continuous (no jump).
    final cx = size.width * (0.50 + 0.18 * math.sin(t * 0.9));
    final cy = size.height * (0.50 + 0.16 * math.cos(t * 0.75));

    // Intensity + reach breathe slowly.
    final intensity = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.05));
    final reach = 0.70 + 0.30 * (0.5 + 0.5 * math.cos(t * 0.8));

    final baseR = math.min(size.width, size.height);
    final r1 = baseR * 0.55 * reach;
    final r2 = baseR * 0.32 * reach;

    void soft(Offset c, double r, Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    // Core + soft halo — one coherent light, not many independent orbs per card.
    soft(Offset(cx, cy), r1, secondary, 0.42 * intensity);
    soft(Offset(cx, cy), r2, primary, 0.55 * intensity);

    // Tiny trailing glint (same light family, offset continuously).
    final tx = cx + size.width * 0.10 * math.cos(t * 0.9 + 0.6);
    final ty = cy + size.height * 0.08 * math.sin(t * 0.9 + 0.6);
    soft(Offset(tx, ty), r2 * 0.55, tertiary, 0.28 * intensity);
  }

  @override
  bool shouldRepaint(covariant _SingleListGlowPainter oldDelegate) {
    return (phase - oldDelegate.phase).abs() > 0.002 ||
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
