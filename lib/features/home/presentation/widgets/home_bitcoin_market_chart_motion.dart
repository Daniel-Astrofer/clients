import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import '../screens/home_screen.dart';

double homeBitcoinChartHeight(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 360) return homeSize(154);
  if (width < 430) return homeSize(174);
  return homeSize(190);
}

class HomeBitcoinChartStateTransition extends StatelessWidget {
  final Widget child;
  const HomeBitcoinChartStateTransition({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: KeroseneMotion.duration(context, KeroseneMotion.medium),
      switchInCurve: KeroseneMotion.entrance,
      switchOutCurve: KeroseneMotion.exit,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}

/// Draws the chart path from left→right (draw-on) when [seriesKey] changes.
class HomeBitcoinChartDrawOn extends StatefulWidget {
  final Object seriesKey;
  final Widget Function(BuildContext context, double progress) builder;

  const HomeBitcoinChartDrawOn({
    super.key,
    required this.seriesKey,
    required this.builder,
  });

  @override
  State<HomeBitcoinChartDrawOn> createState() => _HomeBitcoinChartDrawOnState();
}

class _HomeBitcoinChartDrawOnState extends State<HomeBitcoinChartDrawOn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KeroseneMotion.long,
    )..forward();
  }

  @override
  void didUpdateWidget(covariant HomeBitcoinChartDrawOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesKey != widget.seriesKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (KeroseneMotion.reduceMotion(context)) {
      return widget.builder(context, 1);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return widget.builder(context, t);
      },
    );
  }
}

/// Smoothly animates displayed price when the value jumps.
class HomeBitcoinAnimatedPrice extends StatelessWidget {
  final double price;
  final String Function(double value) formatter;
  final TextStyle style;

  const HomeBitcoinAnimatedPrice({
    super.key,
    required this.price,
    required this.formatter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (KeroseneMotion.reduceMotion(context)) {
      return Text(formatter(price), maxLines: 1, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: price, end: price),
      duration: KeroseneMotion.medium,
      curve: KeroseneMotion.standard,
      builder: (context, value, _) {
        return Text(formatter(value), maxLines: 1, style: style);
      },
    );
  }
}

/// Tween that actually animates between previous and next price.
class HomeBitcoinPriceTicker extends StatefulWidget {
  final double price;
  final String Function(double value) formatter;
  final TextStyle style;

  const HomeBitcoinPriceTicker({
    super.key,
    required this.price,
    required this.formatter,
    required this.style,
  });

  @override
  State<HomeBitcoinPriceTicker> createState() => _HomeBitcoinPriceTickerState();
}

class _HomeBitcoinPriceTickerState extends State<HomeBitcoinPriceTicker> {
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = widget.price;
    _to = widget.price;
  }

  @override
  void didUpdateWidget(covariant HomeBitcoinPriceTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.price - widget.price).abs() > 0.0001) {
      _from = oldWidget.price;
      _to = widget.price;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (KeroseneMotion.reduceMotion(context) || (_to - _from).abs() < 0.0001) {
      return Text(widget.formatter(widget.price),
          maxLines: 1, style: widget.style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(_to),
      tween: Tween(begin: _from, end: _to),
      duration: KeroseneMotion.medium,
      curve: KeroseneMotion.standard,
      builder: (context, value, _) {
        return Text(widget.formatter(value), maxLines: 1, style: widget.style);
      },
    );
  }
}

class HomeBitcoinChartAmbientPulse extends StatefulWidget {
  final Widget child;
  const HomeBitcoinChartAmbientPulse({super.key, required this.child});

  @override
  State<HomeBitcoinChartAmbientPulse> createState() =>
      _HomeBitcoinChartAmbientPulseState();
}

class _HomeBitcoinChartAmbientPulseState
    extends State<HomeBitcoinChartAmbientPulse> {
  @override
  Widget build(BuildContext context) {
    // Static — continuous opacity tickers kill home scroll FPS.
    return widget.child;
  }
}

/// Live pulse on the last point of the chart.
class HomeBitcoinLiveDot extends StatefulWidget {
  final Offset offset;
  final Color color;

  const HomeBitcoinLiveDot({
    super.key,
    required this.offset,
    required this.color,
  });

  @override
  State<HomeBitcoinLiveDot> createState() => _HomeBitcoinLiveDotState();
}

class _HomeBitcoinLiveDotState extends State<HomeBitcoinLiveDot> {
  @override
  Widget build(BuildContext context) {
    // Static endpoint marker — no looping ticker during home scroll.
    return CustomPaint(
      painter: _LiveDotPainter(
        offset: widget.offset,
        color: widget.color,
        t: 1,
      ),
    );
  }
}

class _LiveDotPainter extends CustomPainter {
  final Offset offset;
  final Color color;
  final double t;

  _LiveDotPainter({
    required this.offset,
    required this.color,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(t * math.pi * 2);
    final radius = 3.2 + wave.abs() * 1.4;
    canvas.drawCircle(
      offset,
      radius + 4,
      Paint()..color = color.withValues(alpha: 0.18 + wave.abs() * 0.12),
    );
    canvas.drawCircle(offset, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LiveDotPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.offset != offset ||
        oldDelegate.color != color;
  }
}
