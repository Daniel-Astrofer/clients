import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/performance/kerosene_graphics_policy.dart';

/// Glass panel. Blur is optional and policy-gated so runtime degrade / low-tier
/// fall back to solid glass (+0.05 opacity) without redesign.
class GlassContainer extends ConsumerWidget {
  final double? width;
  final double? height;
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;

  /// When false, never blurs. When true (default), still requires
  /// [KeroseneGraphicsPolicy.allowBackdropBlur] and !reduceMotion.
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color = Colors.black,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(graphicsPolicyProvider);
    final useBlur = enableBlur &&
        policy.allowBackdropBlur &&
        !KeroseneMotion.reduceMotion(context);

    final double effectiveOpacity =
        useBlur ? opacity : (opacity + 0.05).clamp(0.0, 1.0);
    final radius = borderRadius ?? BorderRadius.circular(20);

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: effectiveOpacity),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.2),
              width: 1.5,
            ),
      ),
      child: child,
    );

    if (!useBlur) {
      return RepaintBoundary(
        child: Container(
          margin: margin,
          child: ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.hardEdge,
            child: content,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: radius,
          clipBehavior: Clip.hardEdge,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: content,
          ),
        ),
      ),
    );
  }
}
