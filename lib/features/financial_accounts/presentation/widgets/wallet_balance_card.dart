import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/safe_display_text.dart';

import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import '../providers/balance_settings_provider.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

/// Widget do card de balanço com gráfico circular
class WalletBalanceCard extends ConsumerWidget {
  final Wallet wallet;

  const WalletBalanceCard({super.key, required this.wallet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final money = ref.watch(moneyFormatConfigProvider);
    final selectedCurrency = money.currency;
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final balanceValueLabel = balanceSettings.isHidden
        ? '${MoneyDisplay.tickerSymbolFor(selectedCurrency)} ••••••••'
        : money.formatAmountFromBtc(
            btcAmount: wallet.balance,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
            decimalPlaces: selectedCurrency == Currency.btc
                ? balanceSettings.decimalPlaces
                : null,
          );
    final responsive = context.responsive;
    final balanceLabel = wallet.primaryBalanceLabel;
    // No dual-ledger / "available to send" copy — figure is the spendable (or
    // cold observed) amount; unconfirmed inbound is pending in history only.
    final portfolioLabel = wallet.isColdWallet || wallet.isObservedOnlyBalance
        ? 'On-chain'
        : context.tr.btcAccountsAvailableBalance;
    // Real chart: for custodial, fraction available vs chain observed when diverged.
    final chartPct = _chartPercentage(wallet);
    final chartSize = responsive.isTinyPhone ? 132.0 : 160.0;
    final innerSize = chartSize * 0.625;
    final surface = HomeSurfaceTheme.of(context);
    final progress = KeroseneBrandTokens.bitcoin;

    return Container(
      padding: EdgeInsets.all(responsive.isTinyPhone ? 18 : 24),
      decoration: BoxDecoration(
        color: surface.card,
        borderRadius: BorderRadius.circular(HomeSurfaceTokens.radiusCard),
        border: Border.all(color: surface.panelBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            width: chartSize,
            height: chartSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(chartSize, chartSize),
                  painter: BalanceChartPainter(
                    percentage: chartPct,
                    progressColor: progress,
                    trackColor: surface.surfaceDim,
                  ),
                ),
                Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    color: surface.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    wallet.isColdWallet
                        ? KeroseneIcons.lock
                        : KeroseneIcons.wallet,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            balanceLabel,
            style: TextStyle(
              color: surface.textSecondary,
              fontSize: 14,
              fontFamily: AppTypography.bodyFontFamily,
              fontWeight: AppTypography.w510,
            ),
          ),
          const SizedBox(height: 4),

          // Endereço da carteira (mascarado)
          Text(
            SafeDisplayText.displayAddress(context, wallet.address),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: surface.textMuted,
              fontSize: 12,
              fontFamily: AppTypography.monoFontFamily,
            ),
          ),
          const SizedBox(height: 12),

          // Saldo em BTC
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                balanceValueLabel,
                style: TextStyle(
                  color: surface.textPrimary,
                  fontSize: responsive.isTinyPhone ? 30 : 36,
                  fontFamily: AppTypography.bodyFontFamily,
                  fontWeight: AppTypography.w590,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          Text(
            portfolioLabel,
            style: TextStyle(
              color: surface.textSecondary,
              fontSize: 14,
              fontFamily: AppTypography.bodyFontFamily,
            ),
          ),
          // Cold-only short hint (not dual-ledger). Custodial/internal: no extra dialog.
          if (wallet.isObservedOnlyBalance &&
              wallet.custodyExplanation.trim().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              wallet.custodyExplanation,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: surface.textMuted,
                fontSize: 12,
                fontFamily: AppTypography.bodyFontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full ring when balance is healthy; partial when custodial available ≪ chain.
  static double _chartPercentage(Wallet wallet) {
    if (wallet.isColdWallet || wallet.isObservedOnlyBalance) {
      return wallet.observedSats > 0 ? 1.0 : 0.0;
    }
    final available = wallet.availableSats;
    final observed = wallet.observedSats;
    if (wallet.isCustodialOnchain && observed > 0 && available >= 0) {
      final ratio = available / observed;
      return ratio.clamp(0.0, 1.0);
    }
    return available > 0 || wallet.balance > 0 ? 1.0 : 0.0;
  }
}

/// Painter para o gráfico circular de balanço
class BalanceChartPainter extends CustomPainter {
  final double percentage;
  final Color progressColor;
  final Color trackColor;

  BalanceChartPainter({
    required this.percentage,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 6, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - 6);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + (2 * math.pi * percentage),
      colors: [progressColor.withValues(alpha: 0.55), progressColor],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(BalanceChartPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
