import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/router/mobile_go_router.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/welcome_screen.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';
import '../../goldens/golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget providers(Widget child) => ProviderScope(overrides: [
        authControllerProvider.overrideWith(() =>
            MockAuthController(initialOverride: const AuthUnauthenticated())),
      ], child: child);

  Future<void> welcome(WidgetTester tester, {double scale = 1}) async {
    size(tester);
    await tester.pumpWidget(providers(MaterialApp(
      theme: AppTheme.darkTheme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!),
      home: const WelcomeScreen(),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('entry actions are available below the decorative preview',
      (tester) async {
    await welcome(tester);
    for (final label in ['Create account', 'Already have an account']) {
      final text = find.text(label);
      await tester.ensureVisible(text);
      await tester.pump();
      expect(text.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry buttons respect enlarged text without scaling it down',
      (tester) async {
    await welcome(tester, scale: 2);
    for (final label in ['Create account', 'Already have an account']) {
      final text = find.text(label);
      await tester.ensureVisible(text);
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(
          paragraph.getTransformTo(null).entry(0, 0).abs(), closeTo(1, .001));
      expect(text.hitTestable(), findsOneWidget);
      expect(
          tester
              .getSize(
                  find.ancestor(of: text, matching: find.byType(TextButton)))
              .height,
          greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  for (final signup in [true, false]) {
    testWidgets('welcome opens one real route on repeated taps, signup=$signup',
        (tester) async {
      size(tester);
      final router = buildMobileGoRouter(
          privateRouteBuilder: (child) => child, root: const WelcomeScreen());
      addTearDown(router.dispose);
      await tester.pumpWidget(providers(MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      )));
      await tester.pumpAndSettle();
      final action = find.text(signup ? 'Criar conta' : 'Já tenho conta');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
          find.byType(signup ? SignupFlowScreen : LoginScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      final other = find.text(signup ? 'Já tenho conta' : 'Criar conta');
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(
          find.byType(signup ? LoginScreen : SignupFlowScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
