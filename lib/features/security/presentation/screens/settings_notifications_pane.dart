import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/services/background_service.dart';
import 'package:kerosene/core/services/notification_service.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';

import 'settings_formatters.dart';
import 'settings_section_components.dart';

class SettingsNotificationsPane extends ConsumerStatefulWidget {
  const SettingsNotificationsPane({super.key});

  @override
  ConsumerState<SettingsNotificationsPane> createState() =>
      _SettingsNotificationsPaneState();
}

class _SettingsNotificationsPaneState
    extends ConsumerState<SettingsNotificationsPane> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final preferences = ref.watch(alertPreferencesProvider);
    final devicesAsync = ref.watch(activeDeviceTokensProvider);
    final deviceRows = devicesAsync.when<List<Widget>>(
      data: (devices) => _deviceRows(context, devices),
      loading: () => [
        SettingsSectionRow(
          icon: KeroseneIcons.device,
          title: tr.settingsNotifDevicesSection,
          subtitle: tr.settingsNotifDevicesLoading,
          onTap: null,
        ),
      ],
      error: (_, __) => [
        SettingsSectionRow(
          icon: KeroseneIcons.warning,
          title: tr.settingsNotifDevicesUnavailableTitle,
          subtitle: tr.settingsNotifDevicesUnavailableSubtitle,
          onTap: null,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.settingsNotifTitle,
          style: AppTypography.newsreader(
            color: KeroseneBrandTokens.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          tr.settingsNotifSubtitle,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textSecondary,
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
                  ? tr.settingsNotifBackgroundOn
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
            SettingsSectionRow(
              icon: KeroseneIcons.moveHorizontal,
              title: tr.settingsNotifFinancialTitle,
              subtitle: tr.settingsNotifFinancialSubtitle,
              trailing: SettingsReadonlySwitch(
                value: preferences.transactionAlertsEnabled,
              ),
              onTap: () => ref
                  .read(alertPreferencesProvider.notifier)
                  .setTransactionAlertsEnabled(
                    !preferences.transactionAlertsEnabled,
                  ),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.security,
              title: tr.settingsNotifSecurityEventsTitle,
              subtitle: tr.settingsNotifSecurityEventsSubtitle,
              trailing: SettingsReadonlySwitch(
                value: preferences.securityAlertsEnabled,
              ),
              onTap: () => ref
                  .read(alertPreferencesProvider.notifier)
                  .setSecurityAlertsEnabled(
                    !preferences.securityAlertsEnabled,
                  ),
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
              onTap: () => ref
                  .read(alertPreferencesProvider.notifier)
                  .setMarketAlertsEnabled(
                    !preferences.marketAlertsEnabled,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsNotifDevicesSection,
          children: deviceRows,
        ),
      ],
    );
  }

  List<Widget> _deviceRows(BuildContext context, List<DeviceToken> devices) {
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
        SettingsSectionRow(
          icon: KeroseneIcons.device,
          title: token.platform.isEmpty
              ? tr.settingsNotifDeviceFallback
              : token.platform,
          subtitle: settingsDeviceTokenSubtitle(token),
          trailing: TextButton(
            onPressed: () => _revokeDevice(context, token),
            style: TextButton.styleFrom(
              foregroundColor: KeroseneBrandTokens.textSecondary,
              textStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            child: Text(tr.settingsNotifRevoke),
          ),
          onTap: null,
        ),
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
    setState(() => _saving = true);
    try {
      if (enabled) {
        final confirmed = await _confirmBackgroundAlerts();
        if (!confirmed) {
          return;
        }

        final granted = await NotificationService().requestPermissions();
        if (!granted) {
          if (mounted) {
            AppNotice.showWarning(
              context,
              title: context.tr.settingsNotifPermissionTitle,
              message: context.tr.settingsNotifPermissionMessage,
            );
          }
          return;
        }
        await startBackgroundService();
      } else {
        await stopBackgroundService();
      }
      await ref
          .read(alertPreferencesProvider.notifier)
          .setBackgroundAlertsEnabled(enabled);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeDevice(BuildContext context, DeviceToken token) async {
    final tr = context.tr;
    final result = await ref
        .read(notificationRepositoryProvider)
        .revokeDeviceToken(token.id);
    result.fold(
      (failure) => AppNotice.showError(
        context,
        title: tr.settingsNotifRevokeFailedTitle,
        message: failure.message,
      ),
      (_) {
        ref.invalidate(activeDeviceTokensProvider);
        AppNotice.showInfo(
          context,
          title: tr.settingsNotifRevokedTitle,
          message: tr.settingsNotifRevokedMessage,
        );
      },
    );
  }
}

class _BackgroundAlertsConsentDialog extends StatelessWidget {
  const _BackgroundAlertsConsentDialog();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: context.responsive.formConstraints,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: KeroseneBrandTokens.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
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
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Icon(
                      KeroseneIcons.notifications,
                      color: KeroseneBrandTokens.textPrimary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tr.settingsNotifBackgroundDialogTitle,
                      style: AppTypography.newsreader(
                        color: KeroseneBrandTokens.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 1.05,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr.settingsNotifBackgroundDialogBody,
                style: AppTypography.bodyMedium.copyWith(
                  color: KeroseneBrandTokens.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
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
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: KeroseneBrandTokens.textSecondary,
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
    );
  }
}
