import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/generic/app_primary_navigation.dart';
import 'package:kerosene/features/security/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  List<Object> takeAllExceptions(WidgetTester tester) {
    final exceptions = <Object>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      exceptions.add(exception!);
    }
    return exceptions;
  }

  Widget localizedApp({
    required Widget home,
    Map<String, WidgetBuilder>? routes,
    String? initialRoute,
  }) {
    return MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: routes ?? const <String, WidgetBuilder>{},
      initialRoute: initialRoute,
      home: initialRoute == null ? home : null,
    );
  }

  Widget routeSurface(String label) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Text(label)),
    );
  }

  Widget navigationOverlaySurface(AppPrimaryDestination destination) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Center(child: Text('route body')),
          AppPrimaryNavigationBar.overlay(currentDestination: destination),
        ],
      ),
    );
  }

  testWidgets('primary navigation overlay no longer renders a nav button', (
    tester,
  ) async {
    await setViewport(tester, const Size(430, 900));
    await tester.pumpWidget(
      localizedApp(
        home: navigationOverlaySurface(AppPrimaryDestination.home),
      ),
    );

    expect(
      find.byKey(const ValueKey('appPrimaryNavigationSurface')),
      findsNothing,
    );
    expect(find.text('Cartão'), findsNothing);
    expect(find.text('Histórico'), findsNothing);
    expect(find.text('Ajustes'), findsNothing);
    expect(takeAllExceptions(tester), isEmpty);
  });

  testWidgets('navigateTo keeps internal screen elements routing correctly', (
    tester,
  ) async {
    await setViewport(tester, const Size(430, 900));
    await tester.pumpWidget(
      localizedApp(
        initialRoute: AppPrimaryDestination.home.routeName,
        home: const SizedBox.shrink(),
        routes: {
          AppPrimaryDestination.home.routeName: (_) =>
              const _InternalNavigationHome(),
          AppPrimaryDestination.card.routeName: (_) =>
              routeSurface('accounts route'),
          AppPrimaryDestination.history.routeName: (_) =>
              routeSurface('history route'),
          AppPrimaryDestination.settings.routeName: (_) =>
              routeSurface('settings route'),
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('openAccountsFromContent')));
    await tester.pumpAndSettle();

    expect(find.text('accounts route'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
  });

  testWidgets('settings screen does not reintroduce the floating nav button', (
    tester,
  ) async {
    await setViewport(tester, const Size(430, 900));
    await tester.pumpWidget(
      const ProviderScope(
        child: _SettingsNavigationHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('appPrimaryNavigationSurface')),
      findsNothing,
    );
    expect(takeAllExceptions(tester), isEmpty);
  });
}

class _InternalNavigationHome extends StatelessWidget {
  const _InternalNavigationHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('openAccountsFromContent'),
          onPressed: () => AppPrimaryNavigationBar.navigateTo(
            context,
            AppPrimaryDestination.card,
          ),
          child: const Text('Abrir contas'),
        ),
      ),
    );
  }
}

class _SettingsNavigationHarness extends StatelessWidget {
  const _SettingsNavigationHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(showPrimaryNavigation: true),
    );
  }
}
