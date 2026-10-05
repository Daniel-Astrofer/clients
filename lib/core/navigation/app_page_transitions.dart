import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/performance/kerosene_graphics_policy.dart';

const Duration kKerosenePageTransitionDuration = KeroseneMotion.medium;
const Duration kKerosenePageReverseTransitionDuration = KeroseneMotion.pageOut;

/// Shared with the in-flow send wizard (destination → wallet → amount → review).
const Duration kKeroseneFlowNavDuration = KeroseneMotion.pageTransition;
const Curve kKeroseneFlowNavCurve = Curves.easeInOutCubic;

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

  return RepaintBoundary(
      child: FadeTransition(
    opacity: incoming,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.035, 0),
        end: Offset.zero,
      ).animate(incoming),
      transformHitTests: false,
      child: child,
    ),
  ));
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

/// Full-bleed horizontal push used by the send flow (and home → send).
///
/// No fade / scale — only a smooth right-to-left slide.
Widget buildKeroseneFlowSlideTransition({
  required Animation<double> animation,
  required Widget child,
}) {
  return buildKeroseneFlowSlideTransitionFrom(
    animation: animation,
    begin: const Offset(1, 0),
    child: child,
  );
}

/// Same as [buildKeroseneFlowSlideTransition] but with a custom slide origin.
Widget buildKeroseneFlowSlideTransitionFrom({
  required Animation<double> animation,
  required Offset begin,
  required Widget child,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: kKeroseneFlowNavCurve,
    reverseCurve: kKeroseneFlowNavCurve,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(curved),
    child: child,
  );
}

CustomTransitionPage<T> keroseneFlowSlidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return keroseneFlowSlidePageFrom<T>(
    key: key,
    child: child,
    begin: const Offset(1, 0),
  );
}

/// Receive flow: screen enters from the left, sliding left-to-right.
CustomTransitionPage<T> keroseneFlowSlideFromLeftPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return keroseneFlowSlidePageFrom<T>(
    key: key,
    child: child,
    begin: const Offset(-1, 0),
  );
}

CustomTransitionPage<T> keroseneFlowSlidePageFrom<T>({
  required LocalKey key,
  required Widget child,
  required Offset begin,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: kKeroseneFlowNavDuration,
    reverseTransitionDuration: kKeroseneFlowNavDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (KeroseneMotion.reduceMotion(context)) {
        return child;
      }
      return buildKeroseneFlowSlideTransitionFrom(
        animation: animation,
        begin: begin,
        child: child,
      );
    },
  );
}
