import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notification_surface.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/design_system/icons.dart';

class NotificationVisuals {
  final AppNotificationTone tone;
  final IconData icon;
  final String categoryLabel;

  const NotificationVisuals({
    required this.tone,
    required this.icon,
    required this.categoryLabel,
  });
}

NotificationVisuals resolveNotificationVisuals(
  BuildContext context,
  SessionNotificationItem item,
) {
  final tr = context.tr;
  switch (item.kind) {
    case SessionNotificationItem.kindSecurityLoginDetected:
      return NotificationVisuals(
        tone: AppNotificationTone.warning,
        icon: KeroseneIcons.shield,
        categoryLabel: tr.notifCategorySecurity,
      );
    case SessionNotificationItem.kindSecurityAdminAccessAttempt:
      return NotificationVisuals(
        tone: AppNotificationTone.warning,
        icon: KeroseneIcons.admin,
        categoryLabel: tr.notifCategorySecurity,
      );
    case SessionNotificationItem.kindSecurityRecoveryCompleted:
      return NotificationVisuals(
        tone: AppNotificationTone.warning,
        icon: KeroseneIcons.key,
        categoryLabel: tr.notifCategoryRecovery,
      );
    case SessionNotificationItem.kindAccountCreated:
      return NotificationVisuals(
        tone: _toneForSeverity(item.severity),
        icon: KeroseneIcons.personAdd,
        categoryLabel: tr.notifCategoryAccount,
      );
    case SessionNotificationItem.kindTransferReceived:
      return NotificationVisuals(
        tone: AppNotificationTone.success,
        icon: _isLightningMetadata(item)
            ? KeroseneIcons.bolt
            : KeroseneIcons.southWest,
        categoryLabel: tr.notifCategoryReceived,
      );
    case SessionNotificationItem.kindTransferSent:
      return NotificationVisuals(
        tone: _toneForSeverity(item.severity),
        icon: _isLightningMetadata(item)
            ? KeroseneIcons.bolt
            : KeroseneIcons.northEast,
        categoryLabel: tr.notifCategorySent,
      );
    case SessionNotificationItem.kindPaymentRequestCreated:
      return NotificationVisuals(
        tone: AppNotificationTone.info,
        icon: KeroseneIcons.receipt,
        categoryLabel: tr.notifCategoryPaymentLink,
      );
    case SessionNotificationItem.kindPaymentRequestPaid:
      return NotificationVisuals(
        tone: AppNotificationTone.success,
        icon: KeroseneIcons.verified,
        categoryLabel: tr.notifCategoryPaymentLink,
      );
    case SessionNotificationItem.kindDepositDetected:
      return NotificationVisuals(
        tone: AppNotificationTone.info,
        icon: KeroseneIcons.download,
        categoryLabel: tr.notifCategoryReceived,
      );
    case SessionNotificationItem.kindDepositConfirmed:
      return NotificationVisuals(
        tone: AppNotificationTone.success,
        icon: KeroseneIcons.wallet,
        categoryLabel: tr.notifCategoryReceived,
      );
    case SessionNotificationItem.kindPaymentSent:
      return NotificationVisuals(
        tone: _toneForSeverity(item.severity),
        icon: _isLightningMetadata(item)
            ? KeroseneIcons.bolt
            : KeroseneIcons.send,
        categoryLabel: tr.notifCategorySent,
      );
    case SessionNotificationItem.kindLightningInvoicePaid:
      return NotificationVisuals(
        tone: AppNotificationTone.success,
        icon: KeroseneIcons.bolt,
        categoryLabel: tr.notifCategoryReceived,
      );
    case SessionNotificationItem.kindLightningPaymentSent:
      return NotificationVisuals(
        tone: _toneForSeverity(item.severity),
        icon: KeroseneIcons.bolt,
        categoryLabel: tr.notifCategorySent,
      );
    case SessionNotificationItem.kindLightningPaymentFailed:
      return NotificationVisuals(
        tone: AppNotificationTone.warning,
        icon: KeroseneIcons.bolt,
        categoryLabel: tr.notifCategorySent,
      );
    default:
      final tone = _toneForSeverity(item.severity);
      return NotificationVisuals(
        tone: tone,
        icon: AppNotificationStyle.iconFor(tone),
        categoryLabel: tr.notifCategorySystem,
      );
  }
}

String buildNotificationFooterLabel(
  BuildContext context,
  SessionNotificationItem item,
  String timeLabel,
) {
  final visuals = resolveNotificationVisuals(context, item);
  return '${visuals.categoryLabel} • $timeLabel';
}

AppNotificationTone _toneForSeverity(String severity) {
  switch (severity) {
    case SessionNotificationItem.severitySuccess:
      return AppNotificationTone.success;
    case SessionNotificationItem.severityWarning:
      return AppNotificationTone.warning;
    case SessionNotificationItem.severityError:
      return AppNotificationTone.error;
    case SessionNotificationItem.severityInfo:
    default:
      return AppNotificationTone.info;
  }
}

bool _isLightningMetadata(SessionNotificationItem item) {
  final rail = (item.metadata['rail'] ??
          item.metadata['paymentRail'] ??
          item.metadata['network'] ??
          '')
      .trim()
      .toUpperCase();
  if (rail.contains('LIGHTNING') || rail == 'LN') return true;
  final kind = item.kind.toLowerCase();
  return kind.contains('lightning');
}
