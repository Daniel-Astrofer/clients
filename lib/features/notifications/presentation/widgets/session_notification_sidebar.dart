import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/components/feedback/app_notification_surface.dart';
import 'package:kerosene/design_system/components/generic/push_notification_card.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:kerosene/features/notifications/presentation/notification_visuals.dart';
import 'package:kerosene/features/notifications/presentation/notification_translator.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'notification_sync_status.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

class SessionNotificationSidebar extends ConsumerWidget {
  final VoidCallback? onClose;
  final bool showCloseButton;

  const SessionNotificationSidebar({
    super.key,
    this.onClose,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(sessionStorageScopeProvider);
    bool ownsSession() => ref.read(sessionStorageScopeProvider) == owner;
    final brand = KeroseneBrandTheme.of(context);
    final notifications = ref.watch(sessionNotificationFeedProvider);
    final unreadCount = ref.watch(sessionNotificationUnreadCountProvider);
    final sync = ref.watch(sessionNotificationSyncProvider);
    final queriedEmpty =
        sync.lastSyncedAt != null && !sync.failed && !sync.loading;
    final headerTitle = context.tr.notifCenterTitle;
    final headerSubtitle = context.tr.notifSidebarSubtitle;
    final clearLabel = context.tr.notifCenterClear;
    final emptyStateTitle = context.tr.notifCenterEmptyAlerts;
    final emptyStateMessage = context.tr.notifSidebarEmptyHint;
    final alertLabel = unreadCount == 1
        ? context.tr.notifSidebarUnreadSingular
        : context.tr.notifSidebarUnreadPlural;
    final unreadLabel = '$unreadCount $alertLabel';
    final responsive = context.responsive;
    final sidebarWidth = math.min(
      336.0,
      math.max(0.0, responsive.size.width - responsive.horizontalPadding),
    );
    final horizontalPadding = responsive.isTinyPhone ? 14.0 : 18.0;

    return Material(
        type: MaterialType.transparency,
        child: Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: brand.background,
            border: Border(
              left: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    responsive.isTinyPhone ? 10 : 14,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitle,
                              style: AppTypography.bodyMedium.copyWith(
                                color: brand.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: responsive.isTinyPhone ? 16 : 18,
                                letterSpacing: 0,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              headerSubtitle,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.46),
                                fontSize: responsive.isTinyPhone ? 11 : 12,
                                height: 1.25,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showCloseButton)
                        IconButton(
                          onPressed: () {
                            if (ownsSession()) onClose?.call();
                          },
                          icon: const KeroseneIcon(KeroseneIcons.close),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.68),
                          iconSize: 17,
                          style: IconButton.styleFrom(
                            shape: const RoundedRectangleBorder(),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: brand.surfaceHigh,
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          unreadLabel,
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.74),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: unreadCount == 0
                            ? null
                            : () {
                                if (!ownsSession()) return;
                                ref
                                    .read(sessionNotificationFeedProvider
                                        .notifier)
                                    .markAllRead();
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: unreadCount == 0 ? 0.22 : 0.7,
                              ),
                          shape: const RoundedRectangleBorder(),
                          textStyle: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          context.tr.notifCenterReadAll,
                        ),
                      ),
                      TextButton(
                        onPressed: notifications.isEmpty
                            ? null
                            : () {
                                if (!ownsSession()) return;
                                ref
                                    .read(sessionNotificationFeedProvider
                                        .notifier)
                                    .clear();
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: notifications.isEmpty ? 0.22 : 0.7,
                              ),
                          shape: const RoundedRectangleBorder(),
                          textStyle: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(clearLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: NotificationSyncStatus(onRefresh: () {
                    if (!ownsSession()) return;
                    ref
                        .read(sessionNotificationFeedProvider.notifier)
                        .reloadFromServer();
                  }),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: AppNotificationSurface(
                              title: queriedEmpty
                                  ? emptyStateTitle
                                  : context.tr.notifSyncNoQuery,
                              message: queriedEmpty ? emptyStateMessage : '',
                              tone: AppNotificationTone.neutral,
                              showLeadingIcon: false,
                              borderRadius: 0,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              maxMessageLines: 2,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            18,
                          ),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            final visuals = resolveNotificationVisuals(
                              context,
                              item,
                            );
                            return Container(
                              decoration: BoxDecoration(
                                border: item.read
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.12),
                                      ),
                              ),
                              child: Stack(
                                children: [
                                  PushNotificationCard(
                                    title: NotificationTranslator.resolveTitle(
                                        context, item),
                                    message: NotificationTranslator.resolveBody(
                                        context, item),
                                    footerLabel: buildNotificationFooterLabel(
                                      context,
                                      item,
                                      _footerLabel(context, item.timestamp),
                                    ),
                                    tone: visuals.tone,
                                    leadingIcon: visuals.icon,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      13,
                                      14,
                                      13,
                                    ),
                                    borderRadius: 0,
                                    maxMessageLines: null,
                                    onTap: () {
                                      if (!ownsSession()) return;
                                      ref
                                          .read(
                                            sessionNotificationFeedProvider
                                                .notifier,
                                          )
                                          .markRead(item.id);

                                      if (item.isActionable) {
                                        onClose?.call();
                                        NotificationNavigation.openFromContext(
                                          context,
                                          item,
                                        );
                                      }
                                    },
                                  ),
                                  if (!item.read)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: brand.textPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ));
  }

  String _footerLabel(BuildContext context, DateTime? timestamp) {
    if (timestamp == null) return context.tr.notifDateNotProvided;
    timestamp = AppDateTime.inDisplayZone(context, timestamp);
    final now = AppDateTime.inDisplayZone(context, DateTime.now());
    final difference = now.difference(timestamp);
    if (difference.isNegative) {
      return AppDateTime.formatFull(context, timestamp);
    }

    if (difference.inMinutes < 1) {
      return context.tr.notifBannerNow;
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    }
    if (DateUtils.isSameDay(now, timestamp)) {
      return MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(timestamp),
        alwaysUse24HourFormat:
            MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
      );
    }

    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}
