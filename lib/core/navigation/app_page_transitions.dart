import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/performance/kerosene_graphics_policy.dart';

const Duration kKerosenePageTransitionDuration = KeroseneMotion.medium;
const Duration kKerosenePageReverseTransitionDuration = KeroseneMotion.short;

const PageTransitionsTheme kerosenePageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: KerosenePageTransitionsBuilder(),
    TargetPlatform.fuchsia: KerosenePageTransitionsBuilder(),
    TargetPlatform.iOS: KerosenePageTransitionsBuilder(),
    TargetPlatform.linux: KerosenePageTransitionsBuilder(),
    TargetPlatform.macOS: KerosenePageTransitionsBuilder(),
    TargetPlatform.windows: KerosenePageTransitionsBuilder(),
  },
);

Route<T> keroseneHorizontalRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  final policy = KeroseneGraphicsPolicy.resolve();
  final isLow = policy.tier == GraphicsTier.low;
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration:
        isLow ? KeroseneMotion.fast : kKerosenePageTransitionDuration,
    reverseTransitionDuration:
        isLow ? KeroseneMotion.fast : kKerosenePageReverseTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return buildKeroseneRouteTransition(
        context: context,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

class KerosenePageTransitionsBuilder extends PageTransitionsBuilder {
  const KerosenePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildKeroseneRouteTransition(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

Widget buildKeroseneHorizontalTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final incoming = CurvedAnimation(
    parent: animation,
    curve: KeroseneMotion.entrance,
    reverseCurve: KeroseneMotion.exit,
  );
  final outgoing = CurvedAnimation(
    parent: secondaryAnimation,
    curve: KeroseneMotion.standard,
    reverseCurve: KeroseneMotion.exit,
  );

  return RepaintBoundary(
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.025, 0),
      ).animate(outgoing),
      transformHitTests: false,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.992).animate(outgoing),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.82).animate(outgoing),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(incoming),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.075, 0),
                end: Offset.zero,
              ).animate(incoming),
              transformHitTests: false,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(incoming),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget buildKeroseneRouteTransition({
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  if (KeroseneMotion.reduceMotion(context)) {
    return child;
  }

  // Low-tier: fade only — fewer layers than slide+scale stacks during nav.
  final policy = KeroseneGraphicsPolicy.resolve();
  if (policy.tier == GraphicsTier.low) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: KeroseneMotion.entrance,
      reverseCurve: KeroseneMotion.exit,
    );
    return FadeTransition(opacity: curved, child: child);
  }

  return buildKeroseneHorizontalTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}
