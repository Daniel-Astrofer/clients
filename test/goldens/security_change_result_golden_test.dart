import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/security/presentation/screens/security_change_result_screen.dart';
import 'golden_harness.dart';
import '../features/security/security_pin_management_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final failed in [false, true]) {
      testGoldens('PIN outcome stays usable on compact screens: $theme $failed',
          (tester) async {
        final repository = fixture.PinManagementRepository()
          ..throwError = failed;
        await fixture.pumpPinManagement(tester,
            repository: repository, theme: theme, scale: 1.4);
        await fixture.fillPinManagement(tester);
        await fixture.submitPinManagement(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester,
            'security_pin_${failed ? 'failed' : 'done'}_${theme.name}_compact');
        await fixture.finishPinManagement(tester);
      });
    }
    testGoldens(
        'recovery result reveals public fixture codes only on request: $theme',
        (tester) async {
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(theme),
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 740),
                      textScaler: TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: SecurityChangeResultScreen(
                      title: 'Códigos de recuperação atualizados',
                      body:
                          'Os códigos anteriores foram substituídos. Guarde a nova lista antes de concluir.',
                      ownerScope: 'golden-session',
                      codes: List.generate(
                          10, (i) => 'PUBLIC-RECOVERY-${i + 1}')))),
          size: const Size(320, 740));
      expect(find.text('PUBLIC-RECOVERY-1'), findsNothing);
      await screenMatchesGolden(
          tester, 'security_codes_result_${theme.name}_compact');
      await tester
          .tap(find.byKey(const ValueKey('security-result-view-codes')));
      await tester.pumpAndSettle();
      expect(find.text('PUBLIC-RECOVERY-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
