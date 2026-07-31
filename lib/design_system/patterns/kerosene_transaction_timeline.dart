import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/patterns/kerosene_transaction_row.dart';

/// A chronological list of [KeroseneTransactionRow] items with optional filters.
///
/// Usage:
/// ```dart
/// KeroseneTransactionTimeline(
///   transactions: [...],
///   activeFilter: KeroseneTxFilter.all,
///   onFilterChanged: (filter) => ...,
///   onTransactionTap: (tx) => context.push('/tx/${tx.id}'),
/// )
/// ```
class KeroseneTransactionTimeline extends StatelessWidget {
  final List<KeroseneTimelineItem> transactions;
  final KeroseneTxFilter activeFilter;
  final ValueChanged<KeroseneTxFilter>? onFilterChanged;
  final ValueChanged<KeroseneTimelineItem>? onTransactionTap;
  final VoidCallback? onViewAll;
  final bool compact;

  const KeroseneTransactionTimeline({
    super.key,
    required this.transactions,
    this.activeFilter = KeroseneTxFilter.all,
    this.onFilterChanged,
    this.onTransactionTap,
    this.onViewAll,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter chips
        if (!compact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Row(
              children: KeroseneTxFilter.values.map((filter) {
                final isActive = filter == activeFilter;
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => onFilterChanged?.call(filter),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isActive ? palette.surface : null,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: isActive ? palette.textPrimary : palette.border, width: 1),
                      ),
                      child: Text(filter.label, style: AppTypography.inter(fontSize: 12, color: isActive ? palette.textPrimary : palette.textSecondary, fontWeight: isActive ? AppTypography.w510 : AppTypography.w400)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        if (!compact) SizedBox(height: AppSpacing.sm),

        // Transaction list
        if (transactions.isEmpty)
          Padding(
            padding: EdgeInsets.all(AppSpacing.module),
            child: Text('Nenhuma movimentacao', style: AppTypography.inter(fontSize: 13, color: palette.textDisabled)),
          )
        else
          ...transactions.take(compact ? 5 : transactions.length).map((tx) =>
            KeroseneTransactionRow(
              type: tx.type,
              counterparty: tx.counterparty,
              amount: tx.amount,
              currency: tx.currency,
              status: tx.status,
              timestamp: tx.timestamp,
              isPending: tx.isPending,
              onTap: () => onTransactionTap?.call(tx),
            ),
          ),

        // View all
        if (compact && onViewAll != null && transactions.length > 5) ...[
          SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onViewAll, child: Text('Ver todas')),
        ],
      ],
    );
  }
}

class KeroseneTimelineItem {
  final String id;
  final KeroseneTxType type;
  final String counterparty;
  final String amount;
  final String currency;
  final String status;
  final String timestamp;
  final bool isPending;

  const KeroseneTimelineItem({
    required this.id,
    required this.type,
    required this.counterparty,
    required this.amount,
    required this.currency,
    required this.status,
    required this.timestamp,
    this.isPending = false,
  });
}

enum KeroseneTxFilter {
  all,
  incoming,
  outgoing,
  lightning,
  onchain,
  pending;

  String get label => switch (this) {
        KeroseneTxFilter.all => 'Todas',
        KeroseneTxFilter.incoming => 'Recebidas',
        KeroseneTxFilter.outgoing => 'Enviadas',
        KeroseneTxFilter.lightning => 'Lightning',
        KeroseneTxFilter.onchain => 'On-chain',
        KeroseneTxFilter.pending => 'Pendentes',
      };
}
