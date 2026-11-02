import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

class HistorySyncNotice extends ConsumerWidget {
  final VoidCallback onRefresh;

  const HistorySyncNotice({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(sessionStorageScopeProvider);
    final history = ref.watch(transactionHistoryProvider);
    final last = ref.watch(lastTransactionHistoryProvider);
    final status = ref.watch(transactionHistoryReadinessProvider);
    final online = ref.watch(networkStatusProvider);
    final failed = status.failed || history.hasError;
    final hasRows =
        (history.asData?.value.isNotEmpty ?? false) || last.isNotEmpty;
    if (owner == null ||
        !hasRows ||
        (!history.isLoading && !failed && online)) {
      return const SizedBox.shrink();
    }

    final brand = KeroseneBrandTheme.of(context);
    final title = history.isLoading
        ? context.tr.historySyncUpdating
        : failed
            ? context.tr.historySyncUnavailable
            : context.tr.historySyncSavedData;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            border: Border.all(color: brand.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: KeroseneIcon(
                history.isLoading
                    ? KeroseneIcons.refresh
                    : KeroseneIcons.linkUnavailable,
                size: 18,
                color: brand.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.bodySmall.copyWith(
                            color: brand.textPrimary,
                            fontWeight: FontWeight.w600)),
                    if (failed) ...[
                      const SizedBox(height: 4),
                      Text(context.tr.historySyncKeptData,
                          style: AppTypography.bodySmall
                              .copyWith(color: brand.textSecondary)),
                    ],
                    if (status.lastSyncedAt case final time?) ...[
                      const SizedBox(height: 4),
                      Text(
                          context.tr.historySyncLastQuery(
                              AppDateTime.formatFull(context, time)),
                          style: AppTypography.bodySmall
                              .copyWith(color: brand.textSecondary)),
                    ],
                  ]),
            ),
            if (!history.isLoading)
              IconButton(
                tooltip: context.tr.historySyncRefreshAction,
                onPressed: () {
                  if (!context.mounted ||
                      ref.read(sessionStorageScopeProvider) != owner) {
                    return;
                  }
                  onRefresh();
                },
                icon: KeroseneIcon(KeroseneIcons.refresh,
                    size: 18, color: brand.textSecondary),
              ),
          ]),
        ),
      ),
    );
  }
}
