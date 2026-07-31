import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';

/// The canonical financial surface — a card built from the monochrome stack.
///
/// Uses 1px hairline borders for depth, never drop shadows.
/// Three elevation levels map to the design system surface stack.
///
/// Usage:
/// ```dart
/// KeroseneFinancialSurface(
///   elevation: KeroseneSurfaceElevation.one,
///   child: MyContent(),
/// )
/// ```
class KeroseneFinancialSurface extends StatelessWidget {
  final Widget child;
  final KeroseneSurfaceElevation elevation;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const KeroseneFinancialSurface({
    super.key,
    required this.child,
    this.elevation = KeroseneSurfaceElevation.one,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: elevation.backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(
          color: elevation.borderColor,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Surface elevation levels for [KeroseneFinancialSurface].
///
/// Maps to DESIGN_SYSTEM.md §1.2 Surface Levels.
enum KeroseneSurfaceElevation {
  /// Carbon (#141516) — input fields, subtle surface layer.
  one,

  /// Graphite (#1C1C1F) — mid-elevation panels, nested surfaces.
  two,

  /// Smoke (#23252A) — hover state, deeper card, button surface.
  three;

  Color get backgroundColor => switch (this) {
        KeroseneSurfaceElevation.one => AppColors.carbonSurface,
        KeroseneSurfaceElevation.two => AppColors.graphiteSurface,
        KeroseneSurfaceElevation.three => AppColors.smokeSurface,
      };

  Color get borderColor => switch (this) {
        KeroseneSurfaceElevation.one => AppColors.smokeSurface,
        KeroseneSurfaceElevation.two => AppColors.ashBorder,
        KeroseneSurfaceElevation.three => AppColors.ferriteBorder,
      };
}
