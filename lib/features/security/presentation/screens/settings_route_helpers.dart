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
      context: context,
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
    _settingsRoute(context: context, pageBuilder: (_, __, ___) => page),
  );
}

Future<T?> pushSettingsResultPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(
        _settingsRoute<T>(context: context, pageBuilder: (_, __, ___) => page));

Future<T?> replaceSettingsResultPage<T, TO>(BuildContext context, Widget page,
        {TO? result}) =>
    Navigator.of(context).pushReplacement<T, TO>(
        _settingsRoute<T>(context: context, pageBuilder: (_, __, ___) => page),
        result: result);

PageRouteBuilder<T> _settingsRoute<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: KeroseneMotion.duration(context, KeroseneMotion.medium),
    reverseTransitionDuration:
        KeroseneMotion.duration(context, KeroseneMotion.short),
    pageBuilder: pageBuilder,
    transitionsBuilder: (context, animation, __, child) {
      if (KeroseneMotion.reduceMotion(context)) return child;
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
