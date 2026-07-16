import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/safe_display_text.dart';
import 'package:kerosene/features/movement/screens/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_visuals.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

class TransactionListItem extends ConsumerWidget {
  final Transaction transaction;

  const TransactionListItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = TransactionVisualSpec.fromTransaction(transaction);
    final money = ref.watch(moneyFormatConfigProvider);
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final amountLabel = money.formatFrozenAmountFromBtc(
      btcAmount: transaction.signedAmountBTC,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: transaction.displayAmountUsd,
      displayAmountEur: transaction.displayAmountEur,
      displayAmountBrl: transaction.displayAmountBrl,
      displayBtcUsd: transaction.displayBtcUsd,
      displayBtcEur: transaction.displayBtcEur,
      displayBtcBrl: transaction.displayBtcBrl,
      signed: true,
    );
    final btcAmountLabel = money.formatAmountFromBtc(
      btcAmount: transaction.signedAmountBTC,
      currency: Currency.btc,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      signed: true,
    );

    final title = resolveTransactionActionTitle(context, transaction);
    final counterparty = transaction.isDebit
        ? resolveTransactionToParty(transaction, compactHash: true)
        : resolveTransactionFromParty(transaction);
    final displayAddress = SafeDisplayText.displayAddress(
      context,
      counterparty,
    );
    final cardGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color.lerp(AppColors.hexFF101923, visual.amountColor, 0.18)!,
        Colors.black,
        AppColors.hexFF121A24,
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TransactionDetailScreen.open(context, transaction),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: visual.amountColor.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                TransactionTypeIconBadge(
                  spec: visual,
                  size: 44,
                  iconSize: 20,
                  borderRadius: 14,
                  backgroundColor: AppColors.hexFF111720,
                  borderColor: visual.iconColor.withValues(alpha: 0.24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayAddress,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.4)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: visual.amountColor,
                          ),
                    ),
                    if (money.currency != Currency.btc) ...[
                      const SizedBox(height: 2),
                      Text(
                        btcAmountLabel,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: 0.3),
                            ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      AppDateTime.formatRelative(
                        context,
                        transaction.timestamp,
                      ),
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
