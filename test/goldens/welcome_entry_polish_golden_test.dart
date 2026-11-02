import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/presentation/screens/welcome_screen.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final layout in ['phone', 'large_text', 'landscape', 'desktop']) {
      testGoldens('welcome keeps clear entry actions: $theme $layout',
          (tester) async {
        final size = switch (layout) {
          'large_text' => const Size(320, 740),
          'landscape' => const Size(568, 320),
          'desktop' => const Size(900, 760),
          _ => const Size(390, 844),
        };
        final locale = switch (layout) {
          'large_text' => const Locale('en'),
          'landscape' => const Locale('es'),
          _ => const Locale('pt'),
        };
        await pumpFullScreenGolden(
            tester,
            ProviderScope(
                overrides: [
                  authControllerProvider.overrideWith(() => MockAuthController(
                      initialOverride: const AuthUnauthenticated())),
                ],
                child: Theme(
                    data: AppTheme.themeFor(theme),
                    child: Builder(
                        builder: (context) => Localizations.override(
                            context: context,
                            locale: locale,
                            child: MediaQuery(
                                data: MediaQueryData(
                                    size: size,
                                    textScaler: TextScaler.linear(
                                        layout == 'large_text' ? 1.8 : 1),
                                    disableAnimations: true),
                                child: const WelcomeScreen()))))),
            size: size);
        final image = tester.widget<Image>(find.byType(Image));
        await tester.runAsync(() => precacheImage(
            image.image, tester.element(find.byType(WelcomeScreen))));
        await tester.pump();
        if (layout == 'large_text' || layout == 'landscape') {
          await Scrollable.ensureVisible(
              tester.element(find.widgetWithText(
                  TextButton,
                  layout == 'large_text'
                      ? 'Already have an account'
                      : 'Ya tengo cuenta')),
              alignment: 1);
          await tester.pump();
        }
        await screenMatchesGolden(
            tester, 'welcome_entry_${layout}_${theme.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
