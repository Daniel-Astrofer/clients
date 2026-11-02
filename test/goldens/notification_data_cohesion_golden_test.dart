import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import '../features/notifications/notification_surface_fixture.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final state in ['loading', 'failed', 'known']) {
      testGoldens('inbox query status and undated record: $theme $state',
          (tester) async {
        await pumpNotificationSurface(tester,
            theme: theme,
            status: SessionNotificationSyncState(
                hydrated: true,
                loading: state == 'loading',
                failed: state == 'failed',
                lastSyncedAt: DateTime.utc(2020, 1, 2, 3, 4, 5)));
        await screenMatchesGolden(
            tester, 'notification_data_${state}_${theme.name}');
        expect(tester.takeException(), isNull);
      });
    }
    testGoldens('sidebar keeps saved notices after lookup fails: $theme',
        (tester) async {
      await pumpNotificationSurface(tester,
          theme: theme,
          sidebar: true,
          status: SessionNotificationSyncState(
              hydrated: true,
              failed: true,
              lastSyncedAt: DateTime.utc(2020, 1, 2, 3, 4, 5)));
      await screenMatchesGolden(
          tester, 'notification_data_sidebar_${theme.name}');
      expect(tester.takeException(), isNull);
    });
  }
}
