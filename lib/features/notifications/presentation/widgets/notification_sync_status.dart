import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import '../providers/session_notification_provider.dart';

/// Presents query status without treating event timestamps as refresh evidence.
class NotificationSyncStatus extends ConsumerWidget {
  final VoidCallback onRefresh;
  const NotificationSyncStatus({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionNotificationSyncProvider);
    final items = ref.watch(sessionNotificationFeedProvider);
    final brand = KeroseneBrandTheme.of(context);
    final lastQuery = status.lastSyncedAt;
    final queryLabel = lastQuery == null
        ? null
        : context.tr
            .notifSyncLastQuery(AppDateTime.formatFull(context, lastQuery));
    final reading = !status.hydrated &&
        lastQuery == null &&
        !status.loading &&
        !status.failed;
    final known = !status.loading && !status.failed && lastQuery != null;
    final title = known
        ? queryLabel!
        : status.loading
            ? context.tr.notifSyncUpdating
            : status.failed
                ? context.tr.notifSyncUnavailable
                : reading
                    ? context.tr.notifSyncReading
                    : context.tr.notifSyncSavedData;
    final details = <String>[
      if (status.failed && items.isNotEmpty) context.tr.notifSyncKeptData,
      if (!known && queryLabel != null) queryLabel,
      if (!known && !reading && queryLabel == null && items.isNotEmpty)
        context.tr.notifSyncSavedData,
    ];
    final canRefresh = !status.loading && !reading;
    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(known ? 10 : 14),
        decoration: BoxDecoration(
            border: Border.all(color: brand.border),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KeroseneIcon(
                status.failed
                    ? KeroseneIcons.linkUnavailable
                    : known
                        ? KeroseneIcons.pending
                        : KeroseneIcons.refresh,
                size: 18,
                color: brand.textSecondary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: AppTypography.bodySmall.copyWith(
                        color: known ? brand.textSecondary : brand.textPrimary,
                        fontWeight:
                            known ? FontWeight.w500 : FontWeight.w700))),
            if (known)
              IconButton(
                  onPressed: onRefresh,
                  tooltip: context.tr.notifSyncRefreshAction,
                  icon: KeroseneIcon(KeroseneIcons.refresh,
                      size: 18, color: brand.textSecondary)),
          ]),
          for (final detail in details) ...[
            const SizedBox(height: 6),
            Text(detail,
                style: AppTypography.bodySmall
                    .copyWith(color: brand.textSecondary)),
          ],
          if (canRefresh && !known) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: onRefresh, child: Text(context.tr.tryAgain)),
          ],
        ]));
  }
}
