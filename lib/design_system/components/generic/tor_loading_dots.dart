import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';

/// Shared [GlobalKey] so PIN → home bootstrap reuses the same dots [State]
/// (animation keeps running across the handoff without a second static loader).
class TorLoadingDotsKeys {
  TorLoadingDotsKeys._();

  static final GlobalKey primary = GlobalKey(debugLabel: 'torPrimaryDots');
}

class TorLoadingDots extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final double travel;
  final Color? color;

  const TorLoadingDots({
    super.key,
    this.dotSize = 7,
    this.spacing = 7,
    this.travel = 8,
    this.color,
  });

  @override
  State<TorLoadingDots> createState() => _TorLoadingDotsState();
}

class _TorLoadingDotsState extends State<TorLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KeroseneMotion.torLoadingDots,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume if a parent rebuild paused the ticker (common after route swaps).
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final media = MediaQuery.maybeOf(context);
    final disableAnimations = media?.disableAnimations == true;
    if (!_controller.isAnimating && tickerEnabled && !disableAnimations) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    final width = widget.dotSize * 3 + widget.spacing * 2;
    final travel = widget.travel;

    // Only hard-disable when the platform asks to disable animations entirely.
    // accessibleNavigation alone must not freeze the primary bootstrap loader.
    final media = MediaQuery.maybeOf(context);
    final disableAnimations = media?.disableAnimations == true;

    if (disableAnimations) {
      return SizedBox(
        width: width,
        height: widget.dotSize + (travel > 0 ? travel : widget.dotSize * 0.35),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => _Dot(
              size: widget.dotSize,
              color: color.withValues(alpha: 0.72),
              left: index == 0 ? 0 : widget.spacing,
            ),
          ),
        ),
      );
    }

    // Fixed box: layout never shifts. Vertical travel is optional; scale/alpha
    // always pulse so travel:0 still looks alive.
    final boxHeight =
        widget.dotSize + (travel > 0 ? travel : widget.dotSize * 0.4);
    return SizedBox(
      width: width,
      height: boxHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (index) {
              final phase = (_controller.value + index * 0.18) % 1;
              final wave = math.sin(phase * math.pi * 2);
              final offsetY = travel <= 0 ? 0.0 : wave * (travel / 2);
              // Stronger alpha so the pulse is obvious on dark backgrounds.
              final alpha = 0.28 + 0.72 * ((wave + 1) / 2);
              // Scale pulse even when travel is 0 (static position, living dots).
              final scale = 0.72 + 0.28 * ((wave + 1) / 2);
              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: _Dot(
                    size: widget.dotSize,
                    color: color.withValues(alpha: alpha.clamp(0.22, 1.0)),
                    left: index == 0 ? 0 : widget.spacing,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final double left;
  final Color color;

  const _Dot({required this.size, required this.left, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: left),
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
