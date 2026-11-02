import 'security_profile_view.dart';
import 'security_credential_enrollment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'security_settings_components.dart';
import 'settings_navigation.dart';

/// Authorized passkey/device-key inventory — real data, no placeholders.
class SettingsDevicesScreen extends ConsumerStatefulWidget {
  const SettingsDevicesScreen({super.key});

  @override
  ConsumerState<SettingsDevicesScreen> createState() =>
      _SettingsDevicesScreenState();
}

class _SettingsDevicesScreenState extends ConsumerState<SettingsDevicesScreen> {
  bool? _needsLegacyMigration;
  String? _migrationScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _probeLegacyMigration(),
    );
  }

  Future<void> _probeLegacyMigration() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      if (mounted) {
        setState(() {
          _needsLegacyMigration = false;
          _migrationScope = null;
        });
      }
      return;
    }
    final username = auth.user.username;
    final scope = ref.read(sessionStorageScopeProvider);
    final hasDeviceKey = await DeviceKeyService.instance.hasRegisteredDeviceKey(
      username,
    );
    if (!mounted || ref.read(sessionStorageScopeProvider) != scope) return;
    final hasShaped = await PasskeyService.instance.hasRegisteredPasskey(
      username: username,
    );
    if (!mounted || ref.read(sessionStorageScopeProvider) != scope) return;
    setState(() {
      _needsLegacyMigration = hasShaped && !hasDeviceKey;
      _migrationScope = scope;
    });
  }

  Future<void> _refreshProfile() async {
    ref.invalidate(accountSecurityProfileProvider);
    try {
      await ref.read(accountSecurityProfileProvider.future);
    } catch (_) {
      // SecurityProfileView renders this provider's error, retains the known
      // profile with its lookup time, and disables stale mutation actions.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(sessionStorageScopeProvider);
    ref.listen(sessionStorageScopeProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _probeLegacyMigration();
        });
      }
    });
    final needsLegacyMigration =
        _migrationScope == scope ? _needsLegacyMigration : null;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          onRefresh: _refreshProfile,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl2,
                  AppSpacing.md,
                  AppSpacing.xl2,
                  viewPadding.bottom + AppSpacing.xxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: context.responsive.appColumnConstraints,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsHeader(
                            onClose: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).maybePop();
                            },
                          ),
                          SizedBox(height: AppSpacing.xxl),
                          Text(
                            context.tr.settingsDevicesTitle,
                            style: AppTypography.newsreader(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            context.tr.securityDevicesDescription,
                            style: AppTypography.inter(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.55,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xxl),
                          if (needsLegacyMigration == true) ...[
                            Container(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    context.tr.securityDevicesUpdateKey,
                                    style: AppTypography.inter(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: AppSpacing.sm),
                                  Text(
                                    context.tr.securityDevicesLegacyKeyNotice,
                                    style: AppTypography.inter(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          SecurityProfileView(
                            builder: (profile, current) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PasskeyInventoryCard(
                                  inventory: profile.passkeys,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton.icon(
                                  onPressed: !current
                                      ? null
                                      : () async {
                                          await openCredentialEnrollment(
                                              context,
                                              returnToDevices: true);
                                          if (mounted) {
                                            await _probeLegacyMigration();
                                          }
                                        },
                                  icon: const KeroseneIcon(
                                      KeroseneIcons.biometric),
                                  label: Text(
                                    context.tr.settingsDevicesRegisterPasskey,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
