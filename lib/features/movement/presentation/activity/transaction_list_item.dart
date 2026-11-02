import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/interaction/kerosene_pressable.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_glyph.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/features/movement/presentation/shared/financial_status_badge.dart';

class TransactionListItem extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionListItem({super.key, required this.transaction});

  @override
  ConsumerState<TransactionListItem> createState() =>
      _TransactionListItemState();
}

class _TransactionListItemState extends ConsumerState<TransactionListItem> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);
    final money = ref.watch(moneyFormatConfigProvider);
    final owner = ref.watch(sessionStorageScopeProvider);
    final transaction = widget.transaction;
    final presentation = TransactionPresentation.fromTransaction(
      context,
      transaction,
      displayCurrency: money.currency,
      btcUsd: null,
      btcEur: null,
      btcBrl: null,
      appLocale: money.locale,
      btcDecimalPlaces: money.btcDecimalPlaces,
      includeExpandPayload: false,
    );
    final status =
        FinancialStatusBadge.transaction(context, transaction.status);
    final amount = Text(
      presentation.primaryAmountLabel,
      style: AppTypography.bodyMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
    );
    final heading = Row(children: [
      ActivityGlyph.forAxes(presentation.axes, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          presentation.title,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: KerosenePressable(
        enabled: !_opening && owner?.isNotEmpty == true,
        onPressed: () async {
          if (_opening ||
              !mounted ||
              owner?.isNotEmpty != true ||
              ref.read(sessionStorageScopeProvider) != owner) {
            return;
          }
          setState(() => _opening = true);
          try {
            await TransactionDetailScreen.open(context, transaction);
          } finally {
            if (mounted) setState(() => _opening = false);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 17;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact)
                  heading
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    Flexible(child: amount),
                  ]),
                const SizedBox(height: 10),
                Text(
                  presentation.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 12),
                  amount,
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      KeroseneIcon(status.icon,
                          size: 14, color: palette.textSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(presentation.statusLabel,
                            style: AppTypography.bodySmall
                                .copyWith(color: palette.textSecondary)),
                      ),
                    ]),
                    Text(presentation.tertiary,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textMuted)),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
