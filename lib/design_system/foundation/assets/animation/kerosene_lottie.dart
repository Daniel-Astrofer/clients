import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/assets/animation/kerosene_animation_asset.dart';
import 'package:kerosene/design_system/foundation/assets/animation/kerosene_animation_host.dart';
import 'package:kerosene/design_system/foundation/assets/animation/kerosene_animation_policy.dart';
import 'package:lottie/lottie.dart';

class KeroseneLottie extends StatelessWidget {
  const KeroseneLottie({
    super.key,
    required this.asset,
    this.animation,
    this.semanticLabel,
    this.width,
    this.height,
    this.repeat,
    this.colorFilter,
  });

  KeroseneLottie.asset({
    super.key,
    required this.asset,
    this.semanticLabel,
    this.width,
    this.height,
    bool repeat = false,
    this.colorFilter,
  })  : animation = Lottie.asset(
          asset.path,
          width: width,
          height: height,
          fit: BoxFit.contain,
          repeat: repeat,
          frameBuilder: (context, child, composition) {
            if (composition == null) {
              return SizedBox(width: width, height: height);
            }
            return child;
          },
        ),
        repeat = repeat;

  final KeroseneAnimationAsset asset;
  final Widget? animation;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final bool? repeat;
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    final content = animation == null || colorFilter == null
        ? animation
        : ColorFiltered(colorFilter: colorFilter!, child: animation);
    return KeroseneAnimationHost(
      asset: asset,
      semanticLabel: semanticLabel,
      width: width,
      height: height,
      repeat: repeat ?? KeroseneAnimationPolicy.shouldRepeat(asset),
      child: content,
    );
  }

  static bool assetTypeIsLottie(KeroseneAnimationAsset asset) {
    return asset.path.endsWith('.json');
  }
}
