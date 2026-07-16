import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/monochrome_theme.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/design_system/icons.dart';

class FinancialStatusMeta {
  final String label;
  final Color color;
  final IconData icon;

  const FinancialStatusMeta({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class FinancialStatusBadge extends StatelessWidget {
  final FinancialStatusMeta meta;
  final bool compact;

  const FinancialStatusBadge({
    super.key,
    required this.meta,
    this.compact = false,
  });

  static const Color pendingColor = AppColors.hexFFFBBF24;
  static const Color successColor = AppColors.hexFF10B981;
  static const Color errorColor = AppColors.hexFFEF4444;
  static const Color infoColor = AppColors.hexFF38BDF8;

  static FinancialStatusMeta paymentLink(BuildContext context, String status) {
    final tr = context.tr;
    switch (status.toUpperCase()) {
      case 'PAID':
        return FinancialStatusMeta(
          label: tr.finStatusPaid,
          color: successColor,
          icon: KeroseneIcons.success,
        );
      case 'COMPLETED':
      case 'SETTLED':
      case 'CONFIRMED':
        return FinancialStatusMeta(
          label: tr.finStatusCompleted,
          color: successColor,
          icon: KeroseneIcons.verified,
        );
      case 'EXPIRED':
        return FinancialStatusMeta(
          label: tr.finStatusExpired,
          color: errorColor,
          icon: KeroseneIcons.cancel,
        );
      case 'CANCELLED':
        return FinancialStatusMeta(
          label: tr.finStatusCancelled,
          color: errorColor,
          icon: KeroseneIcons.blocked,
        );
      case 'VERIFYING_ONBOARDING':
      case 'AUTO_RESOLUTION_PENDING':
      case 'VALIDATING':
      case 'QUORUM_SYNC':
      case 'EXECUTING':
        return FinancialStatusMeta(
          label: tr.finStatusValidating,
          color: infoColor,
          icon: KeroseneIcons.sync,
        );
      case 'REQUIRES_RECONCILIATION':
        return FinancialStatusMeta(
          label: tr.finStatusNeedsReview,
          color: pendingColor,
          icon: KeroseneIcons.touch,
        );
      case 'USER_ACTION_REQUIRED':
        return FinancialStatusMeta(
          label: tr.finStatusActionNeeded,
          color: pendingColor,
          icon: KeroseneIcons.touch,
        );
      case 'MEMPOOL':
      case 'DETECTED':
      case 'MEMPOOL_SEEN':
        return FinancialStatusMeta(
          label: tr.finStatusDetected,
          color: infoColor,
          icon: KeroseneIcons.radar,
        );
      case 'PENDING':
      default:
        return FinancialStatusMeta(
          label: tr.finStatusPending,
          color: pendingColor,
          icon: KeroseneIcons.schedule,
        );
    }
  }

  static FinancialStatusMeta transaction(
    BuildContext context,
    TransactionStatus status,
  ) {
    final tr = context.tr;
    switch (status) {
      case TransactionStatus.confirmed:
        return FinancialStatusMeta(
          label: tr.finStatusCompleted,
          color: successColor,
          icon: KeroseneIcons.verified,
        );
      case TransactionStatus.confirming:
        return FinancialStatusMeta(
          label: tr.finStatusConfirming,
          color: pendingColor,
          icon: KeroseneIcons.sync,
        );
      case TransactionStatus.reconciling:
        return FinancialStatusMeta(
          label: tr.finStatusNeedsReview,
          color: pendingColor,
          icon: KeroseneIcons.touch,
        );
      case TransactionStatus.failed:
        return FinancialStatusMeta(
          label: tr.finStatusFailed,
          color: errorColor,
          icon: KeroseneIcons.error,
        );
      case TransactionStatus.cancelled:
        return FinancialStatusMeta(
          label: tr.finStatusCancelled,
          color: errorColor,
          icon: KeroseneIcons.blocked,
        );
      case TransactionStatus.pending:
        return FinancialStatusMeta(
          label: tr.finStatusPending,
          color: pendingColor,
          icon: KeroseneIcons.schedule,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderTone = Color.lerp(monoBorderStrongColor, meta.color, 0.08) ??
        monoBorderStrongColor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: borderTone,
        showShadow: false,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: compact ? 14 : 16, color: monoTextColor),
          SizedBox(width: compact ? 6 : 8),
          Text(
            meta.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: monoTextColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}
