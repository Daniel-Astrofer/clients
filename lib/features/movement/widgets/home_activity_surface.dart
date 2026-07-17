import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Home activity list paper + ink for each ledger balance tab.
///
/// Colored tabs use stronger card gradients and high-contrast dark ink.
/// Total (near-white) keeps standard dark ink — no invert needed.
@immutable
class HomeActivitySurfaceStyle {
  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
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

  const HomeActivitySurfaceStyle({
    required this.gradientTop,
    required this.gradientMid,
    required this.gradientBottom,
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
  });

  /// [viewName] is `HomeLedgerBalanceView.name`.
  static HomeActivitySurfaceStyle forLedgerViewName(String viewName) {
    return switch (viewName) {
      'onChain' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x66FFB04A),
          gradientMid: Color(0x33FF9A2E),
          gradientBottom: Color(0x00FF9A2E),
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
        ),
      'cold' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x666BB3E8),
          gradientMid: Color(0x334A9AD4),
          gradientBottom: Color(0x004A9AD4),
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
        ),
      'platform' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x44D8DDE4),
          gradientMid: Color(0x22C8CED8),
          gradientBottom: Color(0x00C8CED8),
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
        ),
      _ => const HomeActivitySurfaceStyle(
          // Total — near white, no invert.
          gradientTop: Color(0x22F0F0F2),
          gradientMid: Color(0x11E8E8EC),
          gradientBottom: Color(0x00E8E8EC),
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
        ),
    };
  }
}

/// Soft static gradient behind the transaction list only.
///
/// No sparkle circles, no looping blobs — just a vertical wash clipped to
/// the list bounds so it never leaks into funds distribution or other home
/// sections.
class HomeActivityListWash extends StatelessWidget {
  final HomeActivitySurfaceStyle style;
  final Widget child;

  const HomeActivityListWash({
    super.key,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              style.gradientTop,
              style.gradientMid,
              style.gradientBottom,
            ],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        child: Padding(
          // Slight inset so the wash reads as list backdrop, not full screen.
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: child,
        ),
      ),
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
