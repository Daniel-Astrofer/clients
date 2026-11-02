import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/security/presentation/screens/security_lookup.dart';
import 'package:kerosene/features/security/presentation/screens/security_totp_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_backup_codes_screen.dart';
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final page in ['totp-active', 'totp-inactive', 'backup']) {
      testGoldens('security state remains readable: $theme $page',
          (tester) async {
        final active = page != 'totp-inactive';
        await pumpFullScreenGolden(
            tester,
            ProviderScope(
                overrides: [
                  securityStatusProvider.overrideWith((ref) async =>
                      AccountSecurityStatusResult(totpEnabled: active)),
                  backupCodesStatusProvider.overrideWith((ref) async =>
                      BackupCodesStatusResult(
                          enabled: active, remainingCodes: active ? 8 : 0)),
                ],
                child: Theme(
                    data: AppTheme.themeFor(theme),
                    child: MediaQuery(
                        data: const MediaQueryData(
                            size: Size(320, 740),
                            textScaler: TextScaler.linear(1.4),
                            disableAnimations: true),
                        child: page == 'backup'
                            ? const SettingsBackupCodesScreen()
                            : const SecurityTotpScreen()))),
            size: const Size(320, 740));
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(
            tester, 'security_lookup_${page}_${theme.name}');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final updating in [false, true]) {
      testGoldens(
          'lookup notice identifies the retained timestamps: $theme $updating',
          (tester) async {
        final status = SecurityLookup<bool>();
        final codes = SecurityLookup<int>();
        status.observe('fixture', const AsyncData(true),
            now: DateTime(2020, 1, 1, 12));
        codes.observe('fixture', const AsyncData(8),
            now: DateTime(2020, 1, 1, 12, 1));
        status.observe(
            'fixture',
            updating
                ? const AsyncLoading()
                : AsyncError(StateError('PRIVATE'), StackTrace.current));
        codes.observe(
            'fixture',
            updating
                ? const AsyncLoading()
                : AsyncError(StateError('PRIVATE'), StackTrace.current));
        await pumpFullScreenGolden(
            tester,
            Theme(
                data: AppTheme.themeFor(theme),
                child: MediaQuery(
                    data: const MediaQueryData(
                        size: Size(320, 568),
                        textScaler: TextScaler.linear(1.6),
                        disableAnimations: true),
                    child: Scaffold(
                        body: SafeArea(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: SecurityLookupNotice(sources: [
                                  (label: 'Autenticador', lookup: status),
                                  (
                                    label: 'Códigos de recuperação',
                                    lookup: codes
                                  ),
                                ], onRetry: () {})))))),
            size: const Size(320, 568));
        expect(find.textContaining('Última consulta:'), findsNWidgets(2));
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester,
            'security_lookup_${updating ? 'updating' : 'failed'}_${theme.name}');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
