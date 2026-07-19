import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/domain/payment_security_guards.dart';
import 'package:kerosene/features/movement/widgets/transaction_value_entry_surface.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';

class SendAmountStep extends StatelessWidget {
  final VoidCallback onBack;
  final ValueNotifier<String> amount;
  final Currency selectedCurrency;
  final double lockedAmountBtc;
  final bool hasPaymentLink;
  final double? btcUsd;
  final double? btcEur;
  final double? btcBrl;
  final Wallet? wallet;
  final SendDestinationAnalysis destination;
  final SendFeeQuote feeQuote;
  final bool isLoading;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onContinue;
  final double Function(String amountValue) resolveAmountBtc;
  final VoidCallback? onFiatReferenceTap;
  final NetworkFeeTier feeTier;
  final ValueChanged<NetworkFeeTier>? onFeeTierChanged;

  const SendAmountStep({
    super.key,
    required this.onBack,
    required this.amount,
    required this.selectedCurrency,
    required this.lockedAmountBtc,
    required this.hasPaymentLink,
    required this.btcUsd,
    required this.btcEur,
    required this.btcBrl,
    required this.wallet,
    required this.destination,
    required this.feeQuote,
    required this.isLoading,
    required this.onAmountChanged,
    required this.onContinue,
    required this.resolveAmountBtc,
    this.onFiatReferenceTap,
    this.feeTier = NetworkFeeTier.standard,
    this.onFeeTierChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: amount,
      builder: (context, amountValue, child) {
        final appLocale = Localizations.localeOf(context);
        final amountBtc = resolveAmountBtc(amountValue);
        final amountLocked = hasPaymentLink || lockedAmountBtc > 0;
        final secondaryLabel = selectedCurrency == Currency.btc
            ? formatFiatReference(
                btcAmount: amountBtc,
                btcUsd: btcUsd,
                btcEur: btcEur,
                btcBrl: btcBrl,
                appLocale: appLocale,
              )
            : '≈ ${MoneyDisplay.formatCompact(
                amount: amountBtc,
                currency: Currency.btc,
                maxDecimalPlaces: 8,
                appLocale: appLocale,
              )}';
        final totalDebitedBtc =
            destination.isExternal ? feeQuote.totalDebitedBtc : amountBtc;
        final insufficientBalance = wallet != null &&
            amountBtc > 0 &&
            !feeQuote.isLoading &&
            feeQuote.networkFeeCertainty != NetworkFeeCertainty.loading &&
            totalDebitedBtc > wallet!.balance + 0.000000009;
        final quoteExpired = destination.isOnChain && feeQuote.isQuoteExpired;
        final canContinue = amountBtc > 0 &&
            !isLoading &&
            !quoteExpired &&
            (!destination.isOnChain || feeQuote.isReadyForOnchainSubmit) &&
            !(destination.isLightning && feeQuote.isLoading) &&
            !insufficientBalance;

        final feeLabel = _feeLabel(context);
        final warningLabel = insufficientBalance
            ? SendMoneyCopy.insufficientBalance(context)
            : (quoteExpired
                ? context.tr.sendFeeQuoteExpired
                : null);

        return TransactionValueEntrySurface(
          onBack: onBack,
          amountInput: amountValue,
          unitLabel: MoneyDisplay.tickerSymbolFor(selectedCurrency),
          currency: selectedCurrency,
          fiatReference: secondaryLabel,
          configuration: _TransparencyHierarchyPanel(
            destination: destination,
            feeQuote: feeQuote,
            feeTier: feeTier,
            onFeeTierChanged: onFeeTierChanged,
          ),
          showKeypad: !amountLocked,
          onKeyTap: amountLocked
              ? null
              : (key) {
                  final next = MoneyDisplay.applyKeypadInput(
                    currentValue: amountValue,
                    key: key,
                    currency: selectedCurrency,
                    maxLength: selectedCurrency == Currency.btc ? 16 : 14,
                  );
                  onAmountChanged(next);
                },
          onCurrencyTap: amountLocked ? null : onFiatReferenceTap,
          availableLabel: wallet == null
              ? null
              : MoneyDisplay.formatCompact(
                  amount: wallet!.balance,
                  currency: Currency.btc,
                  maxDecimalPlaces: 8,
                  appLocale: appLocale,
                ),
          feeLabel: null, // Now handled by TransparencyHierarchyPanel
          warningLabel: warningLabel,
          quickActions: amountLocked || wallet == null
              ? const []
              : const [
                  (label: '25%', key: 'pct_25'),
                  (label: '50%', key: 'pct_50'),
                  (label: '100%', key: 'pct_100'),
                ],
          onQuickAction: amountLocked || wallet == null
              ? null
              : (key) => _applyQuickPercent(
                    key: key,
                    amountBtcAvailable: wallet!.balance,
                    feeBtc: destination.isExternal &&
                            feeQuote.networkFeeCertainty ==
                                NetworkFeeCertainty.known
                        ? feeQuote.networkFeeBtc
                        : 0,
                  ),
          ctaLabel: context.tr.continueButton,
          ctaEnabled: canContinue,
          isBusy: isLoading || feeQuote.isLoading,
          onCta: onContinue,
        );
      },
    );
  }

  String? _feeLabel(BuildContext context) {
    if (destination.isLightning) {
      if (feeQuote.networkFeeCertainty ==
          NetworkFeeCertainty.unknownUntilPay) {
        return context.tr.sendFeeEstimatedAtPayment;
      }
    }
    if (!destination.isOnChain) return null;
    if (feeQuote.isLoading ||
        feeQuote.networkFeeCertainty == NetworkFeeCertainty.loading) {
      return context.tr.sendFeeCalculating;
    }
    if (!feeQuote.isReady && feeQuote.error != null) {
      return context.tr.sendFeeUnavailable;
    }
    if (feeQuote.networkFeeCertainty != NetworkFeeCertainty.known) {
      return null;
    }
    final fee = MoneyDisplay.formatCompact(
      amount: feeQuote.networkFeeBtc,
      currency: Currency.btc,
      maxDecimalPlaces: 8,
    );
    final eta = FeeTierSelection.formatEta(
      feeQuote.estimatedSettlementSeconds,
      context.tr,
      testnetLike: expectedBitcoinNetwork != BitcoinNetworkKind.mainnet &&
          expectedBitcoinNetwork != BitcoinNetworkKind.unknown,
    );
    if (eta.isEmpty) return fee;
    return '$fee · $eta';
  }

  void _applyQuickPercent({
    required String key,
    required double amountBtcAvailable,
    required double feeBtc,
  }) {
    final fraction = switch (key) {
      'pct_25' => 0.25,
      'pct_50' => 0.50,
      'pct_100' => 1.0,
      _ => 0.0,
    };
    if (fraction <= 0) return;

    // Leave room for network fee on external sends when using 100%.
    final spendable =
        (amountBtcAvailable - feeBtc).clamp(0.0, amountBtcAvailable);
    final targetBtc = spendable * fraction;
    if (targetBtc <= 0) {
      onAmountChanged('0');
      return;
    }

    if (selectedCurrency == Currency.btc) {
      onAmountChanged(_trimZeros(targetBtc.toStringAsFixed(8)));
      return;
    }

    final fiat = MoneyDisplay.convertFromBtcAmount(
      btcAmount: targetBtc,
      currency: selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
    onAmountChanged(_trimZeros(fiat.toStringAsFixed(2)));
  }

  String _trimZeros(String value) {
    if (!value.contains('.')) return value;
    return value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _FeeTierBar extends StatelessWidget {
  final NetworkFeeTier selected;
  final ValueChanged<NetworkFeeTier> onSelected;

  const _FeeTierBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final tier in NetworkFeeTier.values) ...[
            if (tier != NetworkFeeTier.values.first) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: selected == tier
                    ? KeroseneBrandTokens.textPrimary
                    : KeroseneBrandTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(tier);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      FeeTierSelection.tierLabel(tier, context.tr),
                      textAlign: TextAlign.center,
                      style: AppTypography.inter(
                        color: selected == tier
                            ? KeroseneBrandTokens.background
                            : KeroseneBrandTokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransparencyHierarchyPanel extends StatelessWidget {
  final SendDestinationAnalysis destination;
  final SendFeeQuote feeQuote;
  final NetworkFeeTier feeTier;
  final ValueChanged<NetworkFeeTier>? onFeeTierChanged;

  const _TransparencyHierarchyPanel({
    required this.destination,
    required this.feeQuote,
    required this.feeTier,
    this.onFeeTierChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!feeQuote.hasAmount) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (destination.isOnChain && onFeeTierChanged != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Velocidade da Transação',
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Taxas menores demoram um pouco mais para confirmar.',
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.help_outline,
                  size: 16,
                  color: KeroseneBrandTokens.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FeeTierBar(
            selected: feeTier,
            onSelected: onFeeTierChanged!,
          ),
          const SizedBox(height: 24),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KeroseneBrandTokens.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: KeroseneBrandTokens.border.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              _AnimatedBreakdownRow(
                label: 'O que ele recebe',
                amountBtc: feeQuote.receiverAmountBtc,
                textColor: KeroseneBrandTokens.textPrimary,
              ),
              if (feeQuote.platformFeeBtc > 0) ...[
                const SizedBox(height: 12),
                _AnimatedBreakdownRow(
                  label: 'Taxa Kerosene',
                  amountBtc: feeQuote.platformFeeBtc,
                  textColor: KeroseneBrandTokens.textMuted,
                  isLoading: feeQuote.isLoading,
                ),
              ],
              if (feeQuote.networkFeeBtc > 0 || destination.isOnChain) ...[
                const SizedBox(height: 12),
                _AnimatedBreakdownRow(
                  label: 'Taxa da Rede (Mineradores)',
                  amountBtc: feeQuote.networkFeeBtc,
                  textColor: KeroseneBrandTokens.textMuted,
                  isLoading: feeQuote.isLoading ||
                      (destination.isOnChain && feeQuote.networkFeeCertainty == NetworkFeeCertainty.loading),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: KeroseneBrandTokens.border, height: 1),
              ),
              _AnimatedBreakdownRow(
                label: 'Sairá da sua conta',
                amountBtc: feeQuote.totalDebitedBtc,
                textColor: KeroseneBrandTokens.textPrimary,
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedBreakdownRow extends StatelessWidget {
  final String label;
  final double amountBtc;
  final Color textColor;
  final bool isTotal;
  final bool isLoading;

  const _AnimatedBreakdownRow({
    required this.label,
    required this.amountBtc,
    required this.textColor,
    this.isTotal = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.inter(
            color: textColor,
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (isLoading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KeroseneBrandTokens.textMuted,
            ),
          )
        else
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: amountBtc, end: amountBtc),
            builder: (context, value, child) {
              return RepaintBoundary(
                child: Text(
                  '${MoneyDisplay.formatCompact(amount: value, currency: Currency.btc, maxDecimalPlaces: 8)} BTC',
                  style: AppTypography.inter(
                    color: textColor,
                    fontSize: isTotal ? 15 : 14,
                    fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
