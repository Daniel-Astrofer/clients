import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kerosene/design_system/components/generic/glass_container.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/expense_category.dart';

/// Lista de categorias de despesas - Refatorada
class ExpenseCategoriesList extends ConsumerWidget {
  const ExpenseCategoriesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      ExpenseCategories.subscription,
      ExpenseCategories.grocery,
      ExpenseCategories.shopping,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: categories.asMap().entries.map((entry) {
        return _buildCategoryCard(context, entry.value, entry.key, ref);
      }).toList(),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ExpenseCategory category,
    int index,
    WidgetRef ref,
  ) {
    final money = ref.watch(moneyFormatConfigProvider);
    final amountLabel = money.formatAmountFromBtc(
      btcAmount: category.amountBTC,
      btcUsd: ref.watch(latestBtcPriceProvider),
      btcEur: ref.watch(btcEurPriceProvider),
      btcBrl: ref.watch(btcBrlPriceProvider),
    );
    final ink = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: GlassContainer(
        enableBlur: false,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              category.name.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: ink.withValues(alpha: 0.55),
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amountLabel,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTypography.financialFontFamily,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ).animate(delay: (index * 100).ms).fade().slideX(begin: 0.1, end: 0),
    );
  }
}
