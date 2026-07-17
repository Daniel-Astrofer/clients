import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Home activity list paper + ink for each ledger balance tab.
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
  /// Soft highlight tint for ambient glimmers (low-alpha in the painter).
  final Color glimmer;

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
    required this.glimmer,
  });

  /// [viewName] is `HomeLedgerBalanceView.name`.
  static HomeActivitySurfaceStyle forLedgerViewName(String viewName) {
    return switch (viewName) {
      'onChain' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x55FFB04A),
          gradientMid: Color(0x28FF9A2E),
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
          glimmer: Color(0xFFFFF0D0),
        ),
      'cold' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x556BB3E8),
          gradientMid: Color(0x284A9AD4),
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
          glimmer: Color(0xFFE8F6FF),
        ),
      'platform' => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x40D8DDE4),
          gradientMid: Color(0x20C8CED8),
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
          glimmer: Color(0xFFFFFFFF),
        ),
      _ => const HomeActivitySurfaceStyle(
          gradientTop: Color(0x28F0F0F2),
          gradientMid: Color(0x14E8E8EC),
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
          glimmer: Color(0xFFFFFFFF),
        ),
    };
  }
}

/// Vertical wash + soft continuous glimmers, **clipped to the transaction list**.
///
/// Glimmers are soft radial fades (not hard circles), positions use sin/cos so
/// the 0→1 loop is seamless (no jump when the ticker wraps).
class HomeActivityListWash extends StatefulWidget {
  final HomeActivitySurfaceStyle style;
  final Widget child;

  const HomeActivityListWash({
    super.key,
    required this.style,
    required this.child,
  });

  @override
  State<HomeActivityListWash> createState() => _HomeActivityListWashState();
}

class _HomeActivityListWashState extends State<HomeActivityListWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      // Long period — motion is almost imperceptible, seamless loop.
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Base wash: only paints where the list is, fades out downward.
          Positioned.fill(
            child: IgnorePointer(
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
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Soft glimmers — seamless drift (no hard circle edges, no reset jump).
          if (!reduce)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _phase,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _SoftGlimmerPainter(
                          phase: _phase.value,
                          color: style.glimmer,
                          accent: style.gradientTop,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Soft radial glimmers (NotebookLM-like). All motion is continuous via sin/cos.
class _SoftGlimmerPainter extends CustomPainter {
  final double phase;
  final Color color;
  final Color accent;

  _SoftGlimmerPainter({
    required this.phase,
    required this.color,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Full cycle in sin/cos → seamless when phase wraps 0↔1.
    final t = phase * 2 * math.pi;

    void softGlow({
      required Offset center,
      required double radius,
      required Color c,
      required double peakAlpha,
    }) {
      // Keep glows fully inside bounds so nothing “extrapolates” the list.
      final r = radius.clamp(8.0, math.min(size.width, size.height) * 0.22);
      final cx = center.dx.clamp(r, size.width - r);
      final cy = center.dy.clamp(r, size.height - r);
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          r,
          [
            c.withValues(alpha: peakAlpha),
            c.withValues(alpha: peakAlpha * 0.35),
            c.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        );
      canvas.drawRect(rect, paint);
    }

    // Small, soft, slow — not solid disks.
    softGlow(
      center: Offset(
        size.width * (0.22 + 0.05 * math.sin(t)),
        size.height * (0.14 + 0.04 * math.cos(t * 0.85)),
      ),
      radius: size.width * 0.18,
      c: color,
      peakAlpha: 0.14,
    );
    softGlow(
      center: Offset(
        size.width * (0.72 + 0.04 * math.cos(t * 0.9 + 0.8)),
        size.height * (0.22 + 0.05 * math.sin(t * 0.7 + 0.4)),
      ),
      radius: size.width * 0.15,
      c: accent,
      peakAlpha: 0.10,
    );
    softGlow(
      center: Offset(
        size.width * (0.48 + 0.06 * math.sin(t * 0.55 + 1.6)),
        size.height * (0.48 + 0.04 * math.cos(t * 0.65 + 0.3)),
      ),
      radius: size.width * 0.16,
      c: color,
      peakAlpha: 0.09,
    );
    softGlow(
      center: Offset(
        size.width * (0.30 + 0.04 * math.cos(t * 0.75 + 2.1)),
        size.height * (0.72 + 0.03 * math.sin(t * 0.5 + 1.1)),
      ),
      radius: size.width * 0.12,
      c: color,
      peakAlpha: 0.07,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftGlimmerPainter oldDelegate) {
    // Only repaint when phase changes enough to be visible (~1°).
    return (phase - oldDelegate.phase).abs() > 0.002 ||
        color != oldDelegate.color ||
        accent != oldDelegate.accent;
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
