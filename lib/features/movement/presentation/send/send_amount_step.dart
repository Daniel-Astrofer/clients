import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/fee_tier_selection.dart';
import 'package:kerosene/design_system/components/financial/amount_entry_surface.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/design_system/components/financial/send_flow_chrome.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';
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
  final String destinationLabel; // kept for call-site compatibility
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
    required this.destinationLabel,
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
          showKeypad: false,
          useSystemKeyboard: !amountLocked,
          onAmountTextChanged: amountLocked ? null : onAmountChanged,
          onCurrencyTap: amountLocked ? null : onFiatReferenceTap,
          availableLabel: wallet == null
              ? null
              : MoneyDisplay.formatCompact(
                  amount: wallet!.balance,
                  currency: Currency.btc,
                  maxDecimalPlaces: 8,
                  appLocale: appLocale,
                ),
          feeLabel: null,
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
    final tokens = SendFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Row(
        children: [
          for (final tier in NetworkFeeTier.values) ...[
            if (tier != NetworkFeeTier.values.first)
              SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Material(
                color: selected == tier
                    ? tokens.textPrimary
                    : tokens.surfaceHigh,
                borderRadius: tokens.inputBorderRadius,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(tier);
                  },
                  borderRadius: tokens.inputBorderRadius,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: tokens.minTouch),
                    child: Center(
                      child: Text(
                        FeeTierSelection.tierLabel(tier, context.tr),
                        textAlign: TextAlign.center,
                        style: AppTypography.inter(
                          color: selected == tier
                              ? tokens.background
                              : tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
    final tokens = SendFlowTheme.of(context);
    final showPlatformFee =
        destination.isExternal && (feeQuote.platformFeeBtc > 0 || feeQuote.isLoading);
    final showNetworkFee = destination.isExternal;
    final showFeeCard = showPlatformFee || showNetworkFee;

    // Internal / payment-link: no fee exposure on amount entry.
    if (!showFeeCard && !destination.isOnChain) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (destination.isOnChain && onFeeTierChanged != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Velocidade do envio',
                style: AppTypography.inter(
                  color: tokens.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: tokens.spaceXs + 2),
              Tooltip(
                message: 'Taxas menores demoram um pouco mais para confirmar.',
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.help_outline,
                  size: 16,
                  color: tokens.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd - 4),
          _FeeTierBar(
            selected: feeTier,
            onSelected: onFeeTierChanged!,
          ),
          if (showFeeCard) SizedBox(height: tokens.spaceLg),
        ],
        if (showFeeCard)
          SendFlowCard(
            child: Column(
              children: [
                _AnimatedBreakdownRow(
                  label: 'Quem recebe',
                  amountBtc: feeQuote.receiverAmountBtc,
                  textColor: tokens.textPrimary,
                ),
                if (showPlatformFee) ...[
                  SizedBox(height: tokens.spaceMd - 4),
                  _AnimatedBreakdownRow(
                    label: 'Taxa Kerosene',
                    amountBtc: feeQuote.platformFeeBtc,
                    textColor: tokens.textMuted,
                    isLoading: feeQuote.isLoading,
                  ),
                ],
                if (showNetworkFee) ...[
                  SizedBox(height: tokens.spaceMd - 4),
                  _AnimatedBreakdownRow(
                    label: destination.isLightning
                        ? 'Taxa da rede (na hora do pagamento)'
                        : 'Taxa da rede',
                    amountBtc: feeQuote.networkFeeBtc,
                    textColor: tokens.textMuted,
                    isLoading: feeQuote.isLoading ||
                        (destination.isOnChain &&
                            feeQuote.networkFeeCertainty ==
                                NetworkFeeCertainty.loading),
                    pendingLabel: destination.isLightning &&
                            feeQuote.networkFeeCertainty ==
                                NetworkFeeCertainty.unknownUntilPay
                        ? 'Definida na hora'
                        : null,
                  ),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spaceMd - 4),
                  child: Divider(color: tokens.border, height: 1),
                ),
                _AnimatedBreakdownRow(
                  label: 'Sai da sua conta',
                  amountBtc: feeQuote.totalDebitedBtc,
                  textColor: tokens.textPrimary,
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
  final String? pendingLabel;

  const _AnimatedBreakdownRow({
    required this.label,
    required this.amountBtc,
    required this.textColor,
    this.isTotal = false,
    this.isLoading = false,
    this.pendingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    final valueStyle = tokens.amountBody(
      color: textColor,
      emphasize: isTotal,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.inter(
              color: textColor,
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (isLoading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.textMuted,
            ),
          )
        else if (pendingLabel != null)
          Text(pendingLabel!, style: valueStyle)
        else
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: amountBtc, end: amountBtc),
            builder: (context, value, child) {
              return RepaintBoundary(
                child: Text(
                  '${MoneyDisplay.formatCompact(amount: value, currency: Currency.btc, maxDecimalPlaces: 8)} BTC',
                  style: valueStyle,
                ),
              );
            },
          ),
      ],
    );
  }
}
