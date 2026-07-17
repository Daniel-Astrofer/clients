import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';

/// Cross-fade + soft slide between scenes (no hard cut / flick).
class SceneTransition extends StatelessWidget {
  final HomeScene scene;
  final Widget child;
  final Duration? duration;

  const SceneTransition({
    super.key,
    required this.scene,
    required this.child,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = KeroseneMotion.reduceMotion(context);
    // Longer than medium so theater open/swap feels intentional.
    final d = reduce
        ? Duration.zero
        : (duration ?? const Duration(milliseconds: 560));

    return AnimatedSwitcher(
      duration: d,
      reverseDuration: reduce ? Duration.zero : const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final fade = FadeTransition(opacity: curved, child: child);
        // Soft open from slightly above — never a hard pop-in.
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.10),
            end: Offset.zero,
          ).animate(curved),
          child: fade,
        );
      },
      child: KeyedSubtree(
        key: ValueKey('scene-${scene.id}-${scene.layout.name}'),
        child: child,
      ),
    );
  }
}
