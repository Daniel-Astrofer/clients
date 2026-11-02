import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'golden_harness.dart';
import '../features/security/security_pin_management_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final state in ['loading', 'failed', 'change', 'locked']) {
      testGoldens('PIN management remains explicit: $theme $state',
          (tester) async {
        final repo = fixture.PinManagementRepository();
        if (state == 'loading') repo.pendingRead = Completer<AppPinStatus>();
        if (state == 'failed') repo.readError = true;
        await fixture.pumpPinManagement(tester,
            repository: repo,
            theme: theme,
            scale: 1.4,
            initial: state == 'locked'
                ? const AppPinStatus(
                    enabled: true,
                    configured: true,
                    locked: true,
                    resettableWithTotp: true)
                : state == 'change'
                    ? const AppPinStatus(enabled: true, configured: true)
                    : const AppPinStatus());
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(
            tester, 'pin_management_${state}_${theme.name}');
        if (repo.pendingRead != null) {
          repo.pendingRead!.complete(const AppPinStatus());
          await tester.pumpAndSettle();
        }
        await fixture.finishPinManagement(tester);
      });
    }
    testGoldens('PIN action remains reachable above a compact keyboard: $theme',
        (tester) async {
      await fixture.pumpPinManagement(tester,
          repository: fixture.PinManagementRepository(),
          theme: theme,
          scale: 1.4);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await fixture.fillPinManagement(tester);
      await tester
          .ensureVisible(find.byKey(const ValueKey('security-save-pin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('security-save-pin')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'pin_management_keyboard_${theme.name}');
      await fixture.finishPinManagement(tester);
    });
  }
}
