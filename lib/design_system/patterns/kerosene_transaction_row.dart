import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// The canonical transaction row for activity lists.
///
/// 56px height, full-width tappable. Shows: type icon, counterparty,
/// amount (right-aligned), status badge, timestamp.
///
/// Usage:
/// ```dart
/// KeroseneTransactionRow(
///   type: KeroseneTxType.outgoing,
///   counterparty: 'Maria Silva',
///   amount: '50,00',
///   currency: 'R\$',
///   status: 'Confirmado',
///   timestamp: '14:32',
///   onTap: () => context.push('/tx/123'),
/// )
/// ```
class KeroseneTransactionRow extends StatelessWidget {
  final KeroseneTxType type;
  final String counterparty;
  final String amount;
  final String currency;
  final String status;
  final String timestamp;
  final bool isPending;
  final VoidCallback? onTap;

  const KeroseneTransactionRow({
    super.key,
    required this.type,
    required this.counterparty,
    required this.amount,
    required this.currency,
    required this.status,
    required this.timestamp,
    this.isPending = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.smokeSurface, width: 0.5)),
        ),
        child: Row(
          children: [
            // Type icon
            Icon(
              type.isIncoming ? KeroseneIcons.down : KeroseneIcons.up,
              size: 18,
              color: type.isIncoming
                  ? KeroseneBrandTokens.success
                  : palette.textPrimary,
              semanticLabel: type.isIncoming ? 'Recebido' : 'Enviado',
            ),
            SizedBox(width: AppSpacing.md),

            // Counterparty + status
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(counterparty,
                      style: AppTypography.inter(
                          fontSize: 15,
                          color: palette.textPrimary,
                          fontWeight: AppTypography.w510),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Row(children: [
                    if (isPending) ...[
                      Icon(KeroseneIcons.schedule,
                          size: 12, color: KeroseneBrandTokens.warning),
                      SizedBox(width: 4),
                    ],
                    Text(status,
                        style: AppTypography.inter(
                            fontSize: 12,
                            color: isPending
                                ? KeroseneBrandTokens.warning
                                : palette.textDisabled)),
                  ]),
                ],
              ),
            ),

            // Amount + timestamp
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${type.isIncoming ? '+' : '-'} $currency$amount',
                  style: AppTypography.inter(
                      fontSize: 15,
                      color: type.isIncoming
                          ? KeroseneBrandTokens.success
                          : palette.textPrimary,
                      fontWeight: AppTypography.w590),
                ),
                SizedBox(height: 2),
                Text(timestamp,
                    style: AppTypography.inter(
                        fontSize: 12, color: palette.textDisabled)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum KeroseneTxType {
  incoming,
  outgoing,
  internal;

  bool get isIncoming => this == KeroseneTxType.incoming;
}
