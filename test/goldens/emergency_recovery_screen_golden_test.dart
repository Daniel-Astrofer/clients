import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/application/providers/emergency_recovery_service_provider.dart';
import 'package:kerosene/features/auth/data/emergency_recovery_service.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';

import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';

import 'golden_harness.dart';
import '../features/auth/support/emergency_recovery_fixtures.dart';

class _FixtureRecoveryService implements EmergencyRecoveryService {
  @override
  Future<EmergencyRecoveryStartResult> start(
          EmergencyRecoveryStartDraft draft) async =>
      recoveryFixtureStart;
  @override
  Future<EmergencyRecoveryFinishResult> finish(
          {required String username,
          required EmergencyRecoveryStartResult started,
          required String totpCode}) async =>
      recoveryFixtureFinish;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeGoldenHarness);

  testGoldens('emergency recovery screen', (tester) async {
    await pumpFullScreenGolden(tester, const EmergencyRecoveryScreen());
    await screenMatchesGolden(tester, 'emergency_recovery_screen');
  });

  Future<void> verifyFixture(WidgetTester tester) async {
    final now = DateTime.utc(2026, 10, 11);
    await pumpFullScreenGolden(
        tester,
        ProviderScope(overrides: [
          emergencyRecoveryServiceProvider
              .overrideWithValue(_FixtureRecoveryService()),
          emergencyRecoveryClockProvider.overrideWithValue(() => now),
        ], child: const EmergencyRecoveryScreen()),
        size: const Size(320, 900));
    final fields = find.byType(TextField);
    for (final entry in [
      recoveryFixtureUsername,
      'PUBLIC_FIXTURE_PASSWORD',
      'PUBLIC_FIXTURE_PASSWORD',
      '01010101',
      '02020202',
      '03030303'
    ].asMap().entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Iniciar recuperação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar recuperação'));
    await tester.pumpAndSettle();
  }

  testGoldens('emergency recovery verification compact', (tester) async {
    await verifyFixture(tester);
    final scrollable = find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'emergency_recovery_verify_compact');
  });

  testGoldens('emergency recovery completed codes compact', (tester) async {
    await verifyFixture(tester);
    await tester.enterText(find.byType(TextField), '123456');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar nova chave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar nova chave'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'emergency_recovery_complete_compact');
  });
}
