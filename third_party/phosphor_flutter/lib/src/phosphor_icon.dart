import 'package:flutter/material.dart';

/// Thin wrapper around [Icon] kept for API compatibility with phosphor_flutter.
class PhosphorIcon extends Icon {
  const PhosphorIcon(
    super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    this.duotoneSecondaryOpacity = 0.20,
    this.duotoneSecondaryColor,
  });

  /// Kept for API compatibility; duotone secondary layer is not painted when
  /// icons are plain [IconData] (Flutter 3.44+ IconData is final).
  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;
}
