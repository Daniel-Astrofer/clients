import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'settings_modern_components.dart';

String notificationDevicePlatform(BuildContext context, DeviceToken token) {
  final platform = token.platform.trim();
  return switch (platform.toUpperCase()) {
    'ANDROID' => 'Android',
    'IOS' => 'iOS',
    'WEB' => 'Web',
    _ => platform.isEmpty ? context.tr.settingsNotifDeviceFallback : platform,
  };
}

/// Public references reported by the notification service; no push secret.
List<({String label, String value})> notificationDeviceDetails(
        BuildContext context, DeviceToken token) =>
    [
      (
        label: context.tr.settingsNotifDeviceRecordId,
        value: token.id.isEmpty ? context.tr.homeAmountNotProvided : token.id
      ),
      if (token.deviceRef.isNotEmpty)
        (
          label: context.tr.settingsNotifDeviceReference,
          value: token.deviceRef
        ),
      if (token.tokenRef.isNotEmpty)
        (
          label: context.tr.settingsNotifDeviceTokenReference,
          value: token.tokenRef
        ),
      if (token.appVersion.isNotEmpty)
        (
          label: context.tr.settingsNotifDeviceAppVersion,
          value: token.appVersion
        ),
      if (token.lastSeenAt != null)
        (
          label: context.tr.settingsNotifDeviceLastSeen,
          value: AppDateTime.formatFull(context, token.lastSeenAt!)
        ),
    ];

class NotificationDeviceRegistrationCard extends StatelessWidget {
  final DeviceToken token;
  final bool busy;
  final VoidCallback? onDisable;
  const NotificationDeviceRegistrationCard(
      {super.key,
      required this.token,
      required this.busy,
      required this.onDisable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const KeroseneIcon(KeroseneIcons.device, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Text(notificationDevicePlatform(context, token),
                  style: theme.textTheme.titleMedium)),
        ]),
        const SizedBox(height: 16),
        for (final detail in notificationDeviceDetails(context, token)) ...[
          Text(detail.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SelectableText(detail.value,
              style: AppTypography.technicalMono(
                  fontSize: 12, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 12),
        ],
        Semantics(
            liveRegion: busy,
            child: AppButton(
                key: ValueKey('notification-device-disable-${token.id}'),
                label: busy
                    ? context.tr.settingsNotifDisabling
                    : context.tr.settingsNotifRevoke,
                onPressed: busy ? null : onDisable,
                icon: busy
                    ? CupertinoActivityIndicator(
                        radius: 9,
                        color: theme.colorScheme.onSurface,
                        animating: !KeroseneMotion.reduceMotion(context))
                    : null,
                variant: AppButtonVariant.secondary,
                expand: true)),
      ]),
    );
  }
}

class NotificationDeviceResult extends StatelessWidget {
  final DeviceToken token;
  final bool confirmed;
  final VoidCallback? onRefresh;
  const NotificationDeviceResult(
      {super.key,
      required this.token,
      required this.confirmed,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: SettingsGlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    KeroseneIcon(
                        confirmed
                            ? KeroseneIcons.success
                            : KeroseneIcons.warning,
                        size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            confirmed
                                ? context.tr.settingsNotifRevokedTitle
                                : context.tr.settingsNotifRevokeFailedTitle,
                            style: Theme.of(context).textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 12),
                  Text(confirmed
                      ? context.tr.settingsNotifRevokedMessage
                      : context.tr.settingsNotifRevokeUnconfirmed),
                  const SizedBox(height: 12),
                  Text(context.tr.settingsNotifDeviceRecordId,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(token.id,
                      style: AppTypography.technicalMono(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                          key: const ValueKey(
                              'notification-device-result-refresh'),
                          onPressed: onRefresh,
                          child: Text(context.tr.settingsNotifRefreshDevices))),
                ])),
      );
}
