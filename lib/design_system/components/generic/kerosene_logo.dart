import 'package:flutter/material.dart';

class KeroseneLogo extends StatelessWidget {
  final double size;
  final bool showText;

  /// When null, uses [ColorScheme.onSurface] so light/dark scaffolds stay visible.
  final Color? color;
  final FilterQuality filterQuality;

  const KeroseneLogo({
    super.key,
    this.size = 120,
    this.showText = true,
    this.color,
    this.filterQuality = FilterQuality.high,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Image.asset(
      'assets/logo/kerosene-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: resolvedColor,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: filterQuality,
    );
  }
}
