import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/security/presentation/screens/security_lookup.dart';
import 'package:kerosene/features/security/presentation/screens/notification_device_components.dart';
import 'package:kerosene/features/security/presentation/screens/settings_section_components.dart';
import 'golden_harness.dart';
import '../features/security/notification_devices_journey_test.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final stage in [
      'list',
      'decision',
      'working',
      'confirmed',
      'unconfirmed'
    ]) {
      testGoldens('notification device action stays clear: $theme $stage',
          (tester) async {
        final repository = NotificationDeviceRepositoryFixture();
        if (stage == 'unconfirmed' || stage == 'working') {
          repository.pending = Completer();
        }
        await pumpNotificationDevices(tester, repository,
            theme: theme, textScale: 1.5, size: const Size(320, 740));
        final action = find
            .byKey(ValueKey('notification-device-disable-${deviceFixture.id}'));
        await tester.ensureVisible(action);
        if (stage != 'list') {
          await tester.tap(action);
          await tester.pumpAndSettle();
        }
        if (stage == 'confirmed' ||
            stage == 'unconfirmed' ||
            stage == 'working') {
          await tester
              .tap(find.byKey(const ValueKey('settings-account-confirm')));
          await tester.pump(const Duration(milliseconds: 400));
          if (stage == 'unconfirmed') {
            repository.pending!.complete(
                const Left(ServerFailure(message: 'PRIVATE-DIAGNOSTIC')));
          }
          if (stage != 'working') {
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byType(NotificationDeviceResult));
          }
        }
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(
            tester, 'notification_device_${stage}_${theme.name}',
            customPump: (tester) =>
                tester.pump(const Duration(milliseconds: 50)));
        if (stage == 'working') {
          repository.pending!.complete(const Right(null));
          await tester.pumpAndSettle();
        }
        AppScreenFeedbackBus.clear();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testGoldens(
        'notification snapshot remains readable after failed lookup: $theme',
        (tester) async {
      final lookup = SecurityLookup<List<DeviceToken>>();
      lookup.observe('fixture', const AsyncData([deviceFixture]),
          now: DateTime(2020, 1, 1, 12));
      lookup.observe(
          'fixture', AsyncError(StateError('PRIVATE'), StackTrace.current));
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(theme),
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 740),
                      textScaler: TextScaler.linear(1.5),
                      disableAnimations: true),
                  child: Scaffold(
                      body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SecurityLookupNotice(
                                    sources: [
                                      (
                                        label: 'Aparelhos de notificações',
                                        lookup: lookup
                                      )
                                    ],
                                    failureMessage:
                                        'Não foi possível atualizar a lista. Confira os registros antes de fazer uma alteração.',
                                    onRetry: () {}),
                                SettingsSection(
                                    title: 'Aparelhos de notificações',
                                    children: const [
                                      NotificationDeviceRegistrationCard(
                                          token: deviceFixture,
                                          busy: false,
                                          onDisable: null),
                                    ]),
                              ]))))),
          size: const Size(320, 740));
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'notification_device_stale_${theme.name}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
