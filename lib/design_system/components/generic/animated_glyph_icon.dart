import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';

class AnimatedGlyphIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const AnimatedGlyphIcon({
    super.key,
    required this.icon,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return KeroseneIcon(
      icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
      semanticLabel: semanticLabel,
    );
  }
}
