import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/security/presentation/screens/settings_modern_components.dart';
import '../features/security/settings_local_data_actions_test.dart' as fixture;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    testGoldens(
        'local history confirmation and result stay clear on compact screens: $theme',
        (tester) async {
      await fixture.pumpLocalSettings(tester,
          store: fixture.LocalActionStore(), theme: theme, scale: 1.4);
      await fixture.openLocalWipe(tester);
      expect(find.text('alice'), findsOneWidget);
      expect(
          find.widgetWithText(
              SelectableText, 'complete-public-account-identifier-1234567890'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'settings_local_wipe_${theme.name}_dialog');
      await fixture.confirmLocalWipe(tester);
      await tester.pumpAndSettle();
      AppScreenFeedbackBus.clear();
      await tester.ensureVisible(find.text('Ver extrato'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'settings_local_wipe_${theme.name}_result');
      await fixture.finishLocalSettings(tester);
    });
    testGoldens(
        'settings loading wraps its label with enlarged text and reduced motion: $theme',
        (tester) async {
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(theme),
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 568),
                      textScaler: TextScaler.linear(1.8),
                      disableAnimations: true),
                  child: const Scaffold(
                      body: Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: SettingsLoadingPanel(
                                  label:
                                      'Carregando informações de segurança')))))),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'settings_loading_${theme.name}_large_text');
    });
  }
}
