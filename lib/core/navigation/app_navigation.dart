import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Named destinations work in the mobile router and isolated widget harnesses.
abstract final class AppNavigation {
  static Future<T?> push<T extends Object?>(
      BuildContext context, String location) {
    final router = GoRouter.maybeOf(context);
    return router != null
        ? router.push<T>(location)
        : Navigator.of(context).pushNamed<T>(location);
  }

  static void go(BuildContext context, String location) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(location);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(location, (_) => false);
    }
  }

  static void reset(BuildContext context, String location) =>
      go(context, location);

  static void replace(BuildContext context, String location) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.pushReplacement(location);
    } else {
      Navigator.of(context).pushReplacementNamed(location);
    }
  }

  static void backOrHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      go(context, '/home');
    }
  }
}
