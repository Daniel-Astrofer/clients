import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/background_alerts_runtime_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_notifications_pane.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'golden_harness.dart';

class _Runtime extends BackgroundAlertsRuntimeNotifier {
  _Runtime(this.phase);
  final BackgroundAlertsPhase phase;
  @override
  BackgroundAlertsRuntimeState build() => BackgroundAlertsRuntimeState(phase);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final phase in [
    BackgroundAlertsPhase.waitingForForeground,
    BackgroundAlertsPhase.failedStart
  ]) {
    testGoldens('background alerts show actual status: $phase', (tester) async {
      await pumpFullScreenGolden(
          tester,
          ProviderScope(
              overrides: [
                backgroundAlertsRuntimeProvider
                    .overrideWith(() => _Runtime(phase)),
                activeDeviceTokensProvider
                    .overrideWith((ref) async => const []),
              ],
              child: const MediaQuery(
                data: MediaQueryData(
                    size: Size(320, 568), textScaler: TextScaler.linear(1.7)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: SettingsNotificationsPane())),
              )),
          size: const Size(320, 568));
      await Scrollable.ensureVisible(
        tester.element(find.text('Estado neste aparelho')),
        alignment: 0.05,
      );
      await screenMatchesGolden(
        tester,
        phase == BackgroundAlertsPhase.failedStart
            ? 'background_alerts_failed_large_text'
            : 'background_alerts_pending_large_text',
        customPump: pumpGoldenAnimationFrame,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
