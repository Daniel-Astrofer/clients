import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';

enum AppPrimaryDestination { home, card, history, settings }

extension AppPrimaryDestinationX on AppPrimaryDestination {
  String get routeName {
    switch (this) {
      case AppPrimaryDestination.home:
        return '/home';
      case AppPrimaryDestination.card:
        return '/accounts';
      case AppPrimaryDestination.history:
        return '/activity';
      case AppPrimaryDestination.settings:
        return '/settings';
    }
  }

  String label(BuildContext context) {
    switch (this) {
      case AppPrimaryDestination.home:
        return context.tr.primaryNavHome;
      case AppPrimaryDestination.card:
        return context.tr.primaryNavCard;
      case AppPrimaryDestination.history:
        return context.tr.primaryNavHistory;
      case AppPrimaryDestination.settings:
        return context.tr.primaryNavSettings;
    }
  }

  String get compactFallbackLabel {
    switch (this) {
      case AppPrimaryDestination.home:
        return 'Inicio';
      case AppPrimaryDestination.card:
        return 'Cartao';
      case AppPrimaryDestination.history:
        return 'Historico';
      case AppPrimaryDestination.settings:
        return 'Ajustes';
    }
  }
}

class AppPrimaryNavigationBar {
  const AppPrimaryNavigationBar._();

  static void navigateTo(
    BuildContext context,
    AppPrimaryDestination destination, {
    bool triggerFeedback = true,
  }) {
    final navigator = Navigator.of(context);
    final currentRouteName = ModalRoute.of(context)?.settings.name;
    final targetRouteName = destination.routeName;

    if (currentRouteName == targetRouteName) {
      return;
    }

    if (triggerFeedback) {
      HapticFeedback.selectionClick();
    }

    if (destination == AppPrimaryDestination.home) {
      _returnToHome(navigator);
      return;
    }

    if (currentRouteName == AppPrimaryDestination.home.routeName ||
        currentRouteName == '/home_loading') {
      navigator.pushNamed(targetRouteName);
      return;
    }

    if (_isPrimaryRouteName(currentRouteName)) {
      navigator.pushReplacementNamed(targetRouteName);
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      targetRouteName,
      (route) => route.settings.name == AppPrimaryDestination.home.routeName,
    );
  }

  static void backOrHome(BuildContext context) {
    HapticFeedback.selectionClick();

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
      return;
    }

    navigator.pushReplacementNamed(AppPrimaryDestination.home.routeName);
  }

  static bool _isPrimaryRouteName(String? routeName) {
    return AppPrimaryDestination.values.any(
      (destination) => destination.routeName == routeName,
    );
  }

  static void _returnToHome(NavigatorState navigator) {
    var foundHome = false;
    if (navigator.canPop()) {
      navigator.popUntil((route) {
        foundHome = route.settings.name == AppPrimaryDestination.home.routeName;
        return foundHome || route.isFirst;
      });
    }

    if (!foundHome) {
      navigator.pushNamedAndRemoveUntil(
        AppPrimaryDestination.home.routeName,
        (route) => false,
      );
    }
  }

  static double scaffoldBottomClearance(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xxl;
  }

  static Widget overlay({
    Key? key,
    required AppPrimaryDestination currentDestination,
  }) {
    return _KerosenePrimaryNavigationOverlay(
      key: key,
    );
  }
}

class _KerosenePrimaryNavigationOverlay extends StatelessWidget {
  const _KerosenePrimaryNavigationOverlay({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
