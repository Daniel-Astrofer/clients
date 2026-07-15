import 'package:flutter/material.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

void pushSettingsDeferred(
  BuildContext context,
  Future<void> Function() loadLibrary,
  WidgetBuilder builder,
) {
  Navigator.of(context).push(
    _settingsRoute(
      pageBuilder: (_, __, ___) => DeferredPage(
        loadLibrary: loadLibrary,
        builder: builder,
      ),
    ),
  );
}

/// Push a fully built settings feature screen (no deferred library load).
void pushSettingsPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    _settingsRoute(pageBuilder: (_, __, ___) => page),
  );
}

PageRouteBuilder<void> _settingsRoute({
  required RoutePageBuilder pageBuilder,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: KeroseneMotion.medium,
    reverseTransitionDuration: KeroseneMotion.short,
    pageBuilder: pageBuilder,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: KeroseneMotion.emphasized,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
