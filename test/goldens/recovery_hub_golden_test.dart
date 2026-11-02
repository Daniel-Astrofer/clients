import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_recovery_hub_screen.dart';
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final failed in [false, true]) {
      testGoldens(
          'recovery paths remain legible with lookup failure: $theme $failed',
          (tester) async {
        await pumpFullScreenGolden(
            tester,
            ProviderScope(
                retry: (_, __) => null,
                overrides: [
                  accountSecurityProfileProvider.overrideWith((ref) async {
                    if (failed) throw StateError('PRIVATE-PROFILE');
                    return const AccountSecurityProfile(
                        mode: AccountSecurityMode.shamir);
                  }),
                  securityStatusProvider.overrideWith((ref) async {
                    if (failed) throw StateError('PRIVATE-STATUS');
                    return const AccountSecurityStatusResult(totpEnabled: true);
                  }),
                  backupCodesStatusProvider.overrideWith((ref) async {
                    if (failed) throw StateError('PRIVATE-CODES');
                    return const BackupCodesStatusResult(
                        enabled: true, remainingCodes: 8);
                  }),
                ],
                child: Theme(
                    data: AppTheme.themeFor(theme),
                    child: MediaQuery(
                        data: const MediaQueryData(
                            size: Size(320, 740),
                            textScaler: TextScaler.linear(1.4),
                            disableAnimations: true),
                        child: const SettingsRecoveryHubScreen()))),
            size: const Size(320, 740));
        expect(find.textContaining('PRIVATE-'), findsNothing);
        await screenMatchesGolden(tester,
            'recovery_hub_${failed ? 'failed' : 'known'}_${theme.name}_status');
        await tester.ensureVisible(
            find.byKey(const ValueKey('recovery-open-emergency')));
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester,
            'recovery_hub_${failed ? 'failed' : 'known'}_${theme.name}_actions');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
