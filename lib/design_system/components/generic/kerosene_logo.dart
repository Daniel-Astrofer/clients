import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/animation/kerosene_animation_asset.dart';
import 'package:kerosene/design_system/foundation/assets/animation/kerosene_lottie.dart';

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
    final resolved = color ?? Theme.of(context).colorScheme.onSurface;
    return KeroseneLottie.asset(
      asset: KeroseneAnimationAsset.brandLogo,
      width: size,
      height: size,
      colorFilter: ColorFilter.matrix(_luminanceMaskMatrix(resolved)),
      // A logo is an entrance accent, not a permanent ticker. A finite
      // animation keeps screens settleable and avoids background GPU work.
      repeat: false,
    );
  }

  List<double> _luminanceMaskMatrix(Color color) {
    final red = color.r * 255;
    final green = color.g * 255;
    final blue = color.b * 255;
    final alpha = color.a;

    return <double>[
      0,
      0,
      0,
      0,
      red,
      0,
      0,
      0,
      0,
      green,
      0,
      0,
      0,
      0,
      blue,
      0.2126 * alpha,
      0.7152 * alpha,
      0.0722 * alpha,
      0,
      0,
    ];
  }
}
