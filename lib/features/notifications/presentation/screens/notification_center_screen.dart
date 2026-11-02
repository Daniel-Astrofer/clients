import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/core/navigation/app_navigation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:kerosene/features/notifications/presentation/notification_visuals.dart';
import 'package:kerosene/features/notifications/presentation/notification_translator.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import '../widgets/notification_sync_status.dart';

Future<void> openNotificationCenter(
  BuildContext context, {
  required GlobalKey originKey,
}) {
  final navigator = AppNavigation.maybeNavigatorOf(context);
  if (navigator == null) {
    AppNotice.showError(context,
        title: context.tr.notifDialogOpenFailedTitle,
        message: context.tr.notifDialogOpenFailedMessage);
    return Future.value();
  }
  return navigator.push<void>(_notificationCenterRoute());
}

Route<void> _notificationCenterRoute() {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: KeroseneMotion.pageIn,
    reverseTransitionDuration: KeroseneMotion.medium,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const NotificationCenterScreen();
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = KeroseneMotion.reduceMotion(context);
      final curved = CurvedAnimation(
        parent: animation,
        curve: KeroseneMotion.standard,
        reverseCurve: KeroseneMotion.exit,
      );

      if (reduceMotion) return child;
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  _NotificationCenterFilter _filter = _NotificationCenterFilter.all;
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_reload));
  }

  Future<void> _reload() async {
    if (!mounted) return;
    await ref.read(sessionNotificationFeedProvider.notifier).reloadFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(sessionStorageScopeProvider);
    ref.listen(sessionStorageScopeProvider, (previous, next) {
      if (previous != next) Future.microtask(_reload);
    });
    if (scope == null) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(context.tr.notifSignInToView,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(context.tr.goBack)),
                      ])))));
    }
    bool ownsSession() => ref.read(sessionStorageScopeProvider) == scope;
    final notifications = ref.watch(sessionNotificationFeedProvider);
    final unreadCount = ref.watch(sessionNotificationUnreadCountProvider);
    final sync = ref.watch(sessionNotificationSyncProvider);
    final filtered = _filteredNotifications(notifications);
    final groups = _groupNotifications(context, filtered);
    final reduceMotion = KeroseneMotion.reduceMotion(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: context.responsive.appColumnConstraints,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: _animated(
                      const _NotificationCenterHeader(),
                      reduceMotion: reduceMotion,
                      delay: 80,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  sliver: SliverToBoxAdapter(
                    child: _animated(
                      _NotificationFilterBar(
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      reduceMotion: reduceMotion,
                      delay: 140,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  sliver: SliverToBoxAdapter(
                    child: _animated(
                      _NotificationCenterActions(
                        unreadCount: unreadCount,
                        totalCount: notifications.length,
                        onMarkAllRead: unreadCount == 0
                            ? null
                            : () {
                                if (!ownsSession()) return;
                                ref
                                    .read(sessionNotificationFeedProvider
                                        .notifier)
                                    .markAllRead();
                              },
                        onClear: notifications.isEmpty
                            ? null
                            : () {
                                if (!ownsSession()) return;
                                ref
                                    .read(sessionNotificationFeedProvider
                                        .notifier)
                                    .clear();
                              },
                      ),
                      reduceMotion: reduceMotion,
                      delay: 170,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  sliver: SliverToBoxAdapter(
                      child: NotificationSyncStatus(onRefresh: () {
                    if (ownsSession()) unawaited(_reload());
                  })),
                ),
                if ((sync.loading || !sync.hydrated) && notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if ((sync.failed || sync.lastSyncedAt == null) &&
                    notifications.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(context.tr.notifSyncNoQuery,
                                textAlign: TextAlign.center))),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _animated(
                      _NotificationEmptyState(filter: _filter),
                      reduceMotion: reduceMotion,
                      delay: 200,
                    ),
                  )
                else
                  for (final group in groups) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      sliver: SliverToBoxAdapter(
                        child: _animated(
                          Text(
                            group.label,
                            style: AppTypography.inter(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.58),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                          reduceMotion: reduceMotion,
                          delay: 190,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final item = group.items[index];
                          return _animated(
                            _NotificationCenterCard(
                              item: item,
                              onTap: () {
                                if (ownsSession()) _openNotification(item);
                              },
                            ),
                            reduceMotion: reduceMotion,
                            delay: 220 + index * 45,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: group.items.length,
                      ),
                    ),
                  ],
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SessionNotificationItem> _filteredNotifications(
    List<SessionNotificationItem> notifications,
  ) {
    final filtered = switch (_filter) {
      _NotificationCenterFilter.all => List.of(notifications),
      _NotificationCenterFilter.alerts => notifications
          .where((item) => !_isSecurityNotification(context, item))
          .toList(),
      _NotificationCenterFilter.security => notifications
          .where((item) => _isSecurityNotification(context, item))
          .toList(),
    };
    filtered.sort(
        (a, b) => AppDateTime.compareNewestFirst(a.timestamp, b.timestamp));
    return filtered;
  }

  List<_NotificationDateGroup> _groupNotifications(
    BuildContext context,
    List<SessionNotificationItem> notifications,
  ) {
    final grouped = <String, List<SessionNotificationItem>>{};

    for (final item in notifications) {
      final label = _dateLabel(context, item.timestamp);
      grouped.putIfAbsent(label, () => []).add(item);
    }

    return grouped.entries
        .map((entry) => _NotificationDateGroup(entry.key, entry.value))
        .toList();
  }

  Future<void> _openNotification(SessionNotificationItem item) async {
    final owner = ref.read(sessionStorageScopeProvider);
    await ref.read(sessionNotificationFeedProvider.notifier).markRead(item.id);

    if (!mounted ||
        !item.isActionable ||
        ref.read(sessionStorageScopeProvider) != owner) {
      return;
    }

    await NotificationNavigation.openFromContext(context, item);
  }

  Widget _animated(
    Widget child, {
    required bool reduceMotion,
    required int delay,
  }) {
    if (reduceMotion) {
      return child;
    }

    return child
        .animate()
        .fadeIn(
          duration: KeroseneMotion.statusChange,
          delay: KeroseneMotion.fromMilliseconds(delay.clamp(0, 60).toInt()),
          curve: KeroseneMotion.standard,
          begin: 0.18,
        )
        .slideY(
          begin: 0.035,
          end: 0,
          duration: KeroseneMotion.statusChange,
          delay: KeroseneMotion.fromMilliseconds(delay.clamp(0, 60).toInt()),
          curve: KeroseneMotion.standard,
        );
  }
}

enum _NotificationCenterFilter { all, alerts, security }

class _NotificationDateGroup {
  final String label;
  final List<SessionNotificationItem> items;

  const _NotificationDateGroup(this.label, this.items);
}

class _NotificationCenterHeader extends StatelessWidget {
  const _NotificationCenterHeader();

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.newsreader(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1);
    final back = IconButton(
        tooltip: context.tr.goBack,
        onPressed: () => Navigator.of(context).pop(),
        icon: const KeroseneIcon(KeroseneIcons.back),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        color: Theme.of(context).colorScheme.onSurface);
    final settings = IconButton(
        tooltip: context.tr.notifCenterSettingsTooltip,
        onPressed: () => AppNavigation.push(context, '/settings/notifications'),
        icon: const KeroseneIcon(KeroseneIcons.settings),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        color: Theme.of(context).colorScheme.onSurface);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
          text: TextSpan(text: context.tr.notifCenterTitle, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      final fits = painter.width + 96 <= constraints.maxWidth;
      painter.dispose();
      final title = Text(context.tr.notifCenterTitle, style: titleStyle);
      if (fits) return Row(children: [back, Expanded(child: title), settings]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [back, const Spacer(), settings]),
        const SizedBox(height: 8),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: title),
      ]);
    });
  }
}

class _NotificationFilterBar extends StatelessWidget {
  final _NotificationCenterFilter selected;
  final ValueChanged<_NotificationCenterFilter> onChanged;

  const _NotificationFilterBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _NotificationFilterChip(
          label: context.tr.notifCenterFilterAll,
          icon: null,
          selected: selected == _NotificationCenterFilter.all,
          onTap: () => onChanged(_NotificationCenterFilter.all),
        ),
        _NotificationFilterChip(
          label: context.tr.notifCenterFilterAlerts,
          icon: KeroseneIcons.notifications,
          selected: selected == _NotificationCenterFilter.alerts,
          onTap: () => onChanged(_NotificationCenterFilter.alerts),
        ),
        _NotificationFilterChip(
          label: context.tr.notifCenterFilterSecurity,
          icon: KeroseneIcons.security,
          selected: selected == _NotificationCenterFilter.security,
          onTap: () => onChanged(_NotificationCenterFilter.security),
        ),
      ],
    );
  }
}

class _NotificationCenterActions extends StatelessWidget {
  final int unreadCount;
  final int totalCount;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onClear;

  const _NotificationCenterActions({
    required this.unreadCount,
    required this.totalCount,
    required this.onMarkAllRead,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = totalCount == 0
        ? context.tr.notifCenterZero
        : context.tr.notifCenterUnread(unreadCount);

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            statusLabel,
            style: AppTypography.inter(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        _NotificationActionTextButton(
          label: context.tr.notifCenterReadAll,
          onPressed: onMarkAllRead,
        ),
        _NotificationActionTextButton(
          label: context.tr.notifCenterClear,
          onPressed: onClear,
        ),
      ],
    );
  }
}

class _NotificationActionTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _NotificationActionTextButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: enabled ? 0.72 : 0.22),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      child: Text(label),
    );
  }
}

class _NotificationFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _NotificationFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).scaffoldBackgroundColor;
    final foreground = selected ? surface : ink;

    return Material(
      color: selected ? ink : ink.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? ink : ink.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                KeroseneIcon(icon,
                    size: 13, color: foreground.withValues(alpha: 0.74)),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: AppTypography.inter(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCenterCard extends StatelessWidget {
  final SessionNotificationItem item;
  final VoidCallback onTap;

  const _NotificationCenterCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visuals = resolveNotificationVisuals(context, item);
    final brand = KeroseneBrandTheme.of(context);
    final accent = brand.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
          decoration: BoxDecoration(
            color: KeroseneBrandTheme.of(context).surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.035),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: KeroseneIcon(visuals.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(NotificationTranslator.resolveTitle(context, item),
                        style: AppTypography.bodySmall.copyWith(
                            color: brand.textPrimary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      NotificationTranslator.resolveBody(context, item),
                      style: AppTypography.inter(
                        color: brand.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.42,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_timeLabel(context, item.timestamp),
                        style: AppTypography.bodySmall
                            .copyWith(color: brand.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!item.read)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  final _NotificationCenterFilter filter;

  const _NotificationEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      _NotificationCenterFilter.all => context.tr.notifCenterEmptyAll,
      _NotificationCenterFilter.alerts => context.tr.notifCenterEmptyAlerts,
      _NotificationCenterFilter.security => context.tr.notifCenterEmptySecurity,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: KeroseneBrandTheme.of(context).surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeroseneIcon(
                KeroseneIcons.notificationsOff,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.54),
                size: 26,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.86),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr.notifCenterEmptyHint,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontSize: 12,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSecurityNotification(
  BuildContext context,
  SessionNotificationItem item,
) {
  if (item.kind.startsWith('security_')) {
    return true;
  }

  final category = resolveNotificationVisuals(
    context,
    item,
  ).categoryLabel.trim().toLowerCase();
  return category == 'segurança' ||
      category == 'security' ||
      category == 'seguridad';
}

String _dateLabel(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return context.tr.notifDateNotProvided;
  timestamp = AppDateTime.inDisplayZone(context, timestamp);
  final now = AppDateTime.inDisplayZone(context, DateTime.now());
  final today = DateTime.utc(now.year, now.month, now.day);
  final date = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);

  if (date == today) {
    return context.tr.notifCenterToday;
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return context.tr.notifCenterYesterday;
  }
  return MaterialLocalizations.of(context).formatMediumDate(timestamp);
}

String _timeLabel(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return context.tr.notifDateNotProvided;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(AppDateTime.inDisplayZone(context, timestamp)),
    alwaysUse24HourFormat:
        MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
  );
}
