import 'package:flutter/material.dart';

/// Marks [onBusy] while modal route animations run (push/pop/replace).
///
/// Used to freeze ambient GPU work (aurora, metal) during navigation so the
/// destination's first frames are not fighting continuous fillrate.
class RouteTransitionBusyObserver extends NavigatorObserver {
  RouteTransitionBusyObserver({required this.onBusyChanged});

  final void Function(bool busy) onBusyChanged;
  int _depth = 0;

  void _begin() {
    _depth += 1;
    if (_depth == 1) onBusyChanged(true);
  }

  void _end() {
    if (_depth == 0) return;
    _depth -= 1;
    if (_depth == 0) onBusyChanged(false);
  }

  void _track(Route<dynamic>? route) {
    if (route is! ModalRoute<dynamic>) return;
    final animation = route.animation;
    if (animation == null) return;

    if (animation.status == AnimationStatus.completed ||
        animation.status == AnimationStatus.dismissed) {
      return;
    }

    _begin();
    late final void Function(AnimationStatus) listener;
    listener = (status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        _end();
      }
    };
    animation.addStatusListener(listener);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Only the route being removed has a reverse animation to wait on.
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // No animation in most remove paths — ensure we don't stick busy.
  }
}
