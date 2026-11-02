import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/background_alerts_runtime_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_notifications_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

class _Runtime extends BackgroundAlertsRuntimeNotifier {
  _Runtime(this.initial);
  final BackgroundAlertsPhase initial;
  int retries = 0;
  @override
  BackgroundAlertsRuntimeState build() => BackgroundAlertsRuntimeState(initial);
  @override
  Future<void> retry() async {
    retries++;
    state = const BackgroundAlertsRuntimeState(BackgroundAlertsPhase.running);
  }
}

void main() {
  for (final phase in [
    BackgroundAlertsPhase.waitingForForeground,
    BackgroundAlertsPhase.failedStart,
    BackgroundAlertsPhase.running
  ]) {
    testWidgets('saved preference is distinct from actual service: $phase',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues(
          {AlertPreferencesNotifier.backgroundAlertsKey: true});
      final prefs = await SharedPreferences.getInstance();
      final runtime = _Runtime(phase);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionStorageScopeProvider.overrideWithValue('test-user'),
            backgroundAlertsRuntimeProvider.overrideWith(() => runtime),
            activeDeviceTokensProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MediaQuery(
              data: MediaQueryData(
                  size: Size(320, 568), textScaler: TextScaler.linear(1.7)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: SettingsNotificationsPane())),
            ),
          )));
      await tester.pumpAndSettle();
      expect(
          find.text('Preferência ativada. Confira o estado do serviço abaixo.'),
          findsOneWidget);
      if (phase != BackgroundAlertsPhase.running) {
        expect(find.text('Serviço de alertas iniciado neste aparelho.'),
            findsNothing);
        await tester.ensureVisible(find.text('Tentar Novamente'));
        await tester.tap(find.text('Tentar Novamente'));
        await tester.pumpAndSettle();
        expect(runtime.retries, 1);
        expect(prefs.getBool(AlertPreferencesNotifier.backgroundAlertsKey),
            isTrue);
      }
      expect(find.text('Serviço de alertas iniciado neste aparelho.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
