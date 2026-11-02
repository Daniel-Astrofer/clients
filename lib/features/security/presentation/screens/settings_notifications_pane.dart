import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/background_alerts_runtime_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/app/notifications/notification_service.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

import 'settings_account_confirmation.dart';
import 'security_lookup.dart';
import 'notification_device_components.dart';
import 'settings_section_components.dart';

class SettingsNotificationsPane extends ConsumerStatefulWidget {
  const SettingsNotificationsPane({super.key});

  @override
  ConsumerState<SettingsNotificationsPane> createState() =>
      _SettingsNotificationsPaneState();
}

class _SettingsNotificationsPaneState
    extends ConsumerState<SettingsNotificationsPane>
    with WidgetsBindingObserver {
  bool _saving = false;
  bool _failed = false;
  final Set<String> _revoking = {};
  int _saveGeneration = 0;
  bool _deviceDialogOpen = false;
  bool _foreground = true;
  int _deviceGeneration = 0;
  int? _deviceNoticeSequence;
  final _devices = SecurityLookup<List<DeviceToken>>();
  ({DeviceToken token, bool confirmed})? _deviceOutcome;

  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (_foreground) ref.invalidate(activeDeviceTokensProvider);
  }

  bool _canChangeDevice(DeviceToken token, String owner) {
    if (!mounted ||
        !_foreground ||
        ref.read(sessionStorageScopeProvider)?.trim() != owner) {
      return false;
    }
    final current = ref.read(activeDeviceTokensProvider);
    return token.id.trim().isNotEmpty &&
        securityLookupIsCurrent(current) &&
        current.requireValue.any((item) => item.active && item == token);
  }

  Future<void> _save(Future<void> Function() apply) async {
    if (_saving) return;
    final operation = ++_saveGeneration;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await apply();
    } catch (_) {
      if (mounted && _saveGeneration == operation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && _saveGeneration == operation) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (previous, next) {
      if (previous == next) return;
      _saveGeneration++;
      _deviceGeneration++;
      final notice = _deviceNoticeSequence;
      if (notice != null) AppScreenFeedbackBus.clear(sequence: notice);
      _deviceNoticeSequence = null;
      setState(() {
        _saving = false;
        _failed = false;
        _revoking.clear();
        _deviceDialogOpen = false;
        _deviceOutcome = null;
      });
    });
    final tr = context.tr;
    final preferences = ref.watch(alertPreferencesProvider);
    final runtime = ref.watch(backgroundAlertsRuntimeProvider);
    final devicesAsync = ref.watch(activeDeviceTokensProvider);
    final owner = ref.watch(sessionStorageScopeProvider)?.trim();
    _devices.observe(owner, devicesAsync);
    final deviceRows = _devices.last != null
        ? _deviceRows(context, _devices.last!, owner)
        : devicesAsync.isLoading && owner?.isNotEmpty == true
            ? [
                SettingsSectionRow(
                  icon: KeroseneIcons.device,
                  title: tr.settingsNotifDevicesSection,
                  subtitle: tr.settingsNotifDevicesLoading,
                  onTap: null,
                ),
              ]
            : [
                SettingsSectionRow(
                  icon: KeroseneIcons.warning,
                  title: tr.settingsNotifDevicesUnavailableTitle,
                  subtitle: tr.settingsNotifDevicesUnavailableSubtitle,
                  onTap: () => ref.invalidate(activeDeviceTokensProvider),
                ),
              ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(tr.settingsPreferenceSaveFailed,
                style: AppTypography.bodyMedium
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          ),
        Text(
          tr.settingsNotifTitle,
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
          tr.settingsNotifSubtitle,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsNotifAlertsSection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.notifications,
              title: tr.settingsNotifBackgroundTitle,
              subtitle: preferences.backgroundAlertsEnabled
                  ? tr.runtimeBgPreferenceOn
                  : tr.settingsNotifBackgroundOff,
              trailing: SettingsReadonlySwitch(
                value: preferences.backgroundAlertsEnabled,
              ),
              onTap: _saving
                  ? null
                  : () => _toggleBackgroundAlerts(
                        !preferences.backgroundAlertsEnabled,
                      ),
            ),
            if (preferences.backgroundAlertsEnabled ||
                runtime.phase == BackgroundAlertsPhase.failedStop)
              SettingsSectionRow(
                icon: runtime.phase == BackgroundAlertsPhase.running
                    ? KeroseneIcons.success
                    : KeroseneIcons.info,
                title: tr.runtimeBgTitle,
                subtitle: switch (runtime.phase) {
                  BackgroundAlertsPhase.disabled => tr.runtimeBgDisabled,
                  BackgroundAlertsPhase.signedOut => tr.runtimeBgSignedOut,
                  BackgroundAlertsPhase.unsupported => tr.runtimeBgUnsupported,
                  BackgroundAlertsPhase.waitingForForeground =>
                    tr.runtimeBgWaiting,
                  BackgroundAlertsPhase.starting => tr.runtimeBgStarting,
                  BackgroundAlertsPhase.running => tr.runtimeBgRunning,
                  BackgroundAlertsPhase.permissionRequired =>
                    tr.runtimeBgPermission,
                  BackgroundAlertsPhase.failedStart => tr.runtimeBgStartFailed,
                  BackgroundAlertsPhase.failedStop => tr.runtimeBgStopFailed,
                },
                onTap: null,
              ),
            if (runtime.phase == BackgroundAlertsPhase.permissionRequired ||
                runtime.phase == BackgroundAlertsPhase.failedStart ||
                runtime.phase == BackgroundAlertsPhase.failedStop ||
                runtime.phase == BackgroundAlertsPhase.waitingForForeground)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _saving ? null : _retryBackgroundAlerts,
                    child: Text(tr.retry),
                  ),
                ),
              ),
            SettingsSectionRow(
              icon: KeroseneIcons.info,
              title: tr.settingsUiInAppBannersTitle,
              subtitle: preferences.inAppBannersEnabled
                  ? tr.settingsUiInAppBannersOnSubtitle
                  : tr.settingsUiInAppBannersOffSubtitle,
              trailing: SettingsReadonlySwitch(
                  value: preferences.inAppBannersEnabled),
              onTap: _saving
                  ? null
                  : () => _save(() => ref
                      .read(alertPreferencesProvider.notifier)
                      .setInAppBannersEnabled(
                          !preferences.inAppBannersEnabled)),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.moveHorizontal,
              title: tr.settingsNotifFinancialTitle,
              subtitle: tr.settingsNotifFinancialSubtitle,
              trailing: SettingsReadonlySwitch(
                value: preferences.transactionAlertsEnabled,
              ),
              onTap: _saving
                  ? null
                  : () => _save(() => ref
                      .read(alertPreferencesProvider.notifier)
                      .setTransactionAlertsEnabled(
                        !preferences.transactionAlertsEnabled,
                      )),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.security,
              title: tr.settingsNotifSecurityEventsTitle,
              subtitle: tr.settingsNotifSecurityEventsSubtitle,
              trailing: SettingsReadonlySwitch(
                value: preferences.securityAlertsEnabled,
              ),
              onTap: _saving
                  ? null
                  : () => _save(() => ref
                      .read(alertPreferencesProvider.notifier)
                      .setSecurityAlertsEnabled(
                        !preferences.securityAlertsEnabled,
                      )),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.bitcoin,
              title: tr.settingsNotifMarketTitle,
              subtitle: preferences.marketAlertsEnabled
                  ? tr.settingsNotifMarketOn
                  : tr.settingsNotifMarketOff,
              trailing: SettingsReadonlySwitch(
                value: preferences.marketAlertsEnabled,
              ),
              onTap: _saving
                  ? null
                  : () => _save(() => ref
                      .read(alertPreferencesProvider.notifier)
                      .setMarketAlertsEnabled(
                        !preferences.marketAlertsEnabled,
                      )),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_deviceOutcome case final outcome?) ...[
          NotificationDeviceResult(
              token: outcome.token,
              confirmed: outcome.confirmed,
              onRefresh: devicesAsync.isLoading
                  ? null
                  : () => ref.invalidate(activeDeviceTokensProvider)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_devices.last != null)
          SecurityLookupNotice(
            sources: [
              (label: tr.settingsNotifDevicesSection, lookup: _devices)
            ],
            failureMessage: tr.settingsNotifDevicesStale,
            updatingMessage: tr.settingsNotifDevicesUpdating,
            retryKey: 'notification-devices-retry',
            onRetry: () => ref.invalidate(activeDeviceTokensProvider),
          ),
        SettingsSection(
          title: tr.settingsNotifDevicesSection,
          children: deviceRows,
        ),
      ],
    );
  }

  List<Widget> _deviceRows(
      BuildContext context, List<DeviceToken> devices, String? owner) {
    final tr = context.tr;
    final active = devices.where((device) => device.active).toList();
    if (active.isEmpty) {
      return [
        SettingsSectionRow(
          icon: KeroseneIcons.notificationsOff,
          title: tr.settingsNotifNoDevicesTitle,
          subtitle: tr.settingsNotifNoDevicesSubtitle,
          onTap: null,
        ),
      ];
    }

    return [
      for (final token in active)
        NotificationDeviceRegistrationCard(
            token: token,
            busy: _revoking.contains(token.id),
            onDisable: owner == null ||
                    !_devices.current ||
                    !_foreground ||
                    _deviceDialogOpen ||
                    _revoking.isNotEmpty ||
                    token.id.trim().isEmpty
                ? null
                : () => _revokeDevice(token, owner)),
    ];
  }

  Future<bool> _confirmBackgroundAlerts() async {
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => const _BackgroundAlertsConsentDialog(),
    );
    return result ?? false;
  }

  Future<void> _toggleBackgroundAlerts(bool enabled) async {
    final runtime = ref.read(backgroundAlertsRuntimeProvider.notifier);
    final session = runtime.session;
    await _save(() async {
      if (enabled) {
        final confirmed = await _confirmBackgroundAlerts();
        if (!confirmed) {
          return;
        }

        if (!mounted || runtime.session != session) return;

        final granted = await NotificationService().requestPermissions();
        if (!granted) {
          if (mounted && runtime.session == session) {
            AppNotice.showWarning(
              context,
              title: context.tr.settingsNotifPermissionTitle,
              message: context.tr.settingsNotifPermissionMessage,
            );
          }
          return;
        }
      }
      if (!mounted || runtime.session != session) return;
      await runtime.setEnabled(enabled, expectedSession: session);
    });
  }

  Future<void> _retryBackgroundAlerts() => _save(() async {
        final runtime = ref.read(backgroundAlertsRuntimeProvider.notifier);
        final session = runtime.session;
        if (ref.read(backgroundAlertsRuntimeProvider).phase ==
            BackgroundAlertsPhase.permissionRequired) {
          if (!await NotificationService().requestPermissions()) return;
        }
        if (!mounted || runtime.session != session) return;
        await runtime.retry();
      });

  Future<void> _revokeDevice(DeviceToken token, String owner) async {
    if (_deviceDialogOpen || _revoking.isNotEmpty) return;
    if (owner.isEmpty || !_canChangeDevice(token, owner)) {
      return;
    }
    final generation = _deviceGeneration;
    final tr = context.tr;
    final auth = ref.read(authControllerProvider);
    setState(() => _deviceDialogOpen = true);
    try {
      final confirmed = await confirmAccountSetting(context,
          ownerScope: owner,
          title: tr.settingsNotifDisableConfirmTitle,
          body: tr.settingsNotifDisableConfirmBody,
          confirmLabel: tr.settingsNotifRevoke,
          accountName: auth is AuthAuthenticated ? auth.user.username : null,
          accountId: auth is AuthAuthenticated ? auth.user.id : owner,
          icon: KeroseneIcons.notificationsOff,
          details: [
            (
              label: tr.settingsNotifDeviceFallback,
              value: notificationDevicePlatform(context, token)
            ),
            ...notificationDeviceDetails(context, token),
          ]);
      if (!confirmed ||
          !mounted ||
          !_foreground ||
          _deviceGeneration != generation ||
          ref.read(sessionStorageScopeProvider)?.trim() != owner) {
        return;
      }
      if (!_canChangeDevice(token, owner)) {
        AppNotice.showInfo(context,
            title: tr.settingsNotifDevicesSection,
            message: tr.settingsNotifDeviceDecisionChanged);
        _deviceNoticeSequence = AppScreenFeedbackBus.current.value?.sequence;
        ref.invalidate(activeDeviceTokensProvider);
        return;
      }
      setState(() {
        _deviceDialogOpen = false;
        _revoking.add(token.id);
        _deviceOutcome = null;
      });
      final result = await ref
          .read(notificationRepositoryProvider)
          .revokeDeviceToken(token.id);
      if (!mounted ||
          !_foreground ||
          _deviceGeneration != generation ||
          ref.read(sessionStorageScopeProvider)?.trim() != owner) {
        return;
      }
      final recognized = result.isRight();
      setState(() => _deviceOutcome = (token: token, confirmed: recognized));
      ref.invalidate(activeDeviceTokensProvider);
      result.fold(
        (failure) => AppNotice.showError(
          context,
          title: tr.settingsNotifRevokeFailedTitle,
          message: tr.settingsNotifRevokeUnconfirmed,
        ),
        (_) {
          AppNotice.showInfo(
            context,
            title: tr.settingsNotifRevokedTitle,
            message: tr.settingsNotifRevokedMessage,
          );
        },
      );
      _deviceNoticeSequence = AppScreenFeedbackBus.current.value?.sequence;
    } catch (_) {
      if (mounted &&
          _foreground &&
          _deviceGeneration == generation &&
          ref.read(sessionStorageScopeProvider)?.trim() == owner) {
        setState(() => _deviceOutcome = (token: token, confirmed: false));
        ref.invalidate(activeDeviceTokensProvider);
        AppNotice.showError(context,
            title: tr.settingsNotifRevokeFailedTitle,
            message: tr.settingsNotifRevokeUnconfirmed);
        _deviceNoticeSequence = AppScreenFeedbackBus.current.value?.sequence;
      }
    } finally {
      if (mounted &&
          _deviceGeneration == generation &&
          ref.read(sessionStorageScopeProvider)?.trim() == owner) {
        setState(() {
          _revoking.remove(token.id);
          _deviceDialogOpen = false;
        });
      }
    }
  }
}

class _BackgroundAlertsConsentDialog extends StatelessWidget {
  const _BackgroundAlertsConsentDialog();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: context.responsive.formConstraints,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.06),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.10),
                        ),
                      ),
                      child: KeroseneIcon(
                        KeroseneIcons.notifications,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 23,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        tr.settingsNotifBackgroundDialogTitle,
                        style: AppTypography.newsreader(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                Text(
                  tr.settingsNotifBackgroundDialogBody,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    child: Text(tr.settingsNotifBackgroundDialogConfirm),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    textStyle: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(tr.settingsNotifBackgroundDialogDismiss),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
