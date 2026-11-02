import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import '../features/security/security_credential_flow_test.dart' as fixture;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final failed in [false, true]) {
      testGoldens(
          'credential outcome remains persistent and usable on compact screens: $theme $failed',
          (tester) async {
        final controller = fixture.CredentialUiController()
          ..results.add(failed
              ? const PasskeyRegisterResult.failure(
                  message: 'internal diagnostic')
              : const PasskeyRegisterResult.success());
        await fixture.pumpCredentialUi(tester,
            controller: controller, theme: theme, scale: 1.4);
        await fixture.startCredentialUi(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester,
            'credential_${failed ? 'unconfirmed' : 'done'}_${theme.name}_compact');
        await fixture.finishCredentialUi(tester);
      });
    }
    testGoldens(
        'credential progress uses the account and never displays premature success: $theme',
        (tester) async {
      final controller = fixture.CredentialUiController()
        ..pending = Completer<PasskeyRegisterResult>();
      await fixture.pumpCredentialUi(tester,
          controller: controller, theme: theme, scale: 1.4);
      await fixture.startCredentialUi(tester);
      expect(find.text('Chave de acesso vinculada'), findsNothing);
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'credential_working_${theme.name}_compact');
      controller.pending!.complete(const PasskeyRegisterResult.success());
      await tester.pumpAndSettle();
      await fixture.finishCredentialUi(tester);
    });
    testGoldens(
        'device rebind decision remains account-bound with reachable actions: $theme',
        (tester) async {
      final controller = fixture.CredentialUiController()
        ..results.add(const PasskeyRegisterResult.deviceConflict(
            message: 'internal', data: {'previousUsernameMasked': 'ma***'}));
      await fixture.pumpCredentialUi(tester,
          controller: controller, theme: theme, scale: 1.4);
      await fixture.startCredentialUi(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'credential_rebind_${theme.name}_compact');
      await fixture.finishCredentialUi(tester);
    });
  }
}
