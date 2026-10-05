import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/components/financial/amount_calculator_toolbar.dart';
import 'package:kerosene/design_system/components/financial/amount_entry_surface.dart';
import 'package:kerosene/design_system/components/financial/send_flow_chrome.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/app/widgets/wallet_expand_chip.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';

class SendAmountStep extends StatefulWidget {
  final VoidCallback onBack;
  final ValueNotifier<String> amount;
  final Currency selectedCurrency;
  final double lockedAmountBtc;
  final bool hasPaymentLink;
  final double? btcUsd;
  final double? btcEur;
  final double? btcBrl;
  final Wallet? wallet;
  final List<Wallet> wallets;
  final ValueChanged<Wallet>? onWalletSelected;
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
    this.wallets = const [],
    this.onWalletSelected,
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
  State<SendAmountStep> createState() => _SendAmountStepState();
}

class _SendAmountStepState extends State<SendAmountStep> {
  AmountCalculatorState _calc = const AmountCalculatorState();

  @override
  void didUpdateWidget(covariant SendAmountStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCurrency != widget.selectedCurrency) {
      _calc = AmountCalculatorState(display: widget.amount.value);
    }
  }

  void _onAmountTextChanged(String value) {
    final next = value.trim().isEmpty ? '0' : value;
    final calc = AmountCalculator.onInput(
      state: _calc,
      nextDisplay: next,
      currency: widget.selectedCurrency,
    );
    setState(() => _calc = calc);
    widget.onAmountChanged(calc.display);
  }

  void _onCalculatorOp(String op) {
    final next = AmountCalculator.onOperator(
      state: _calc.copyWith(display: widget.amount.value),
      operator: op,
      currency: widget.selectedCurrency,
    );
    setState(() => _calc = next);
    widget.onAmountChanged(next.display);
    if (next.justResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_calc.justResolved) {
          setState(() => _calc = _calc.copyWith(justResolved: false));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: widget.amount,
      builder: (context, amountValue, child) {
        final appLocale = Localizations.localeOf(context);
        final amountBtc = widget.resolveAmountBtc(amountValue);
        final amountLocked =
            widget.hasPaymentLink || widget.lockedAmountBtc > 0;
        final secondaryLabel = widget.selectedCurrency == Currency.btc
            ? formatFiatReference(
                btcAmount: amountBtc,
                btcUsd: widget.btcUsd,
                btcEur: widget.btcEur,
                btcBrl: widget.btcBrl,
                appLocale: appLocale,
              )
            : '≈ ${MoneyDisplay.formatCompact(amount: amountBtc, currency: Currency.btc, maxDecimalPlaces: 8, appLocale: appLocale)}';
        final totalDebitedBtc = widget.destination.isExternal
            ? widget.feeQuote.totalDebitedBtc
            : amountBtc;
        final insufficientBalance =
            widget.wallet != null &&
            amountBtc > 0 &&
            !widget.feeQuote.isLoading &&
            widget.feeQuote.networkFeeCertainty !=
                NetworkFeeCertainty.loading &&
            totalDebitedBtc > widget.wallet!.balance + 0.000000009;
        final quoteExpired =
            widget.destination.isOnChain && widget.feeQuote.isQuoteExpired;
        final canContinue =
            amountBtc > 0 &&
            !widget.isLoading &&
            !quoteExpired &&
            (!widget.destination.isOnChain ||
                widget.feeQuote.isReadyForOnchainSubmit) &&
            !(widget.destination.isLightning && widget.feeQuote.isLoading) &&
            !insufficientBalance &&
            widget.wallet != null;

        final warningLabel = insufficientBalance
            ? SendMoneyCopy.insufficientBalance(context)
            : (quoteExpired ? context.tr.sendFeeQuoteExpired : null);

        final chip = widget.wallets.isEmpty || widget.onWalletSelected == null
            ? null
            : WalletExpandChip(
                wallets: widget.wallets,
                selectedWallet: widget.wallet ?? widget.wallets.first,
                onWalletSelected: widget.onWalletSelected!,
              );

        return TransactionValueEntrySurface(
          onBack: widget.onBack,
          showCurrencyPrefix: true,
          showCurrencyChip: false,
          amountInput: amountValue,
          expressionLabel: amountLocked
              ? null
              : _calc.expressionLabel(
                  currency: widget.selectedCurrency,
                  locale: appLocale,
                ),
          resolveAmount: _calc.justResolved,
          unitLabel: MoneyDisplay.tickerSymbolFor(widget.selectedCurrency),
          currency: widget.selectedCurrency,
          fiatReference: secondaryLabel,
          configuration: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chip != null) ...[chip, const SizedBox(height: 16)],
              AnimatedSize(
                duration: KeroseneMotion.sendAmount,
                curve: KeroseneMotion.standard,
                alignment: Alignment.topCenter,
                child: _TransparencyHierarchyPanel(
                  destination: widget.destination,
                  feeQuote: widget.feeQuote,
                  feeTier: widget.feeTier,
                  onFeeTierChanged: widget.onFeeTierChanged,
                ),
              ),
            ],
          ),
          showKeypad: false,
          useSystemKeyboard: !amountLocked,
          onAmountTextChanged: amountLocked ? null : _onAmountTextChanged,
          onCurrencyTap: amountLocked ? null : widget.onFiatReferenceTap,
          availableLabel: widget.wallet == null
              ? null
              : MoneyDisplay.formatCompact(
                  amount: widget.wallet!.balance,
                  currency: Currency.btc,
                  maxDecimalPlaces: 8,
                  appLocale: appLocale,
                ),
          feeLabel: null,
          warningLabel: warningLabel,
          // Order: cotação → % → disponível
          quickActions: amountLocked || widget.wallet == null
              ? const []
              : const [
                  (label: '25%', key: 'pct_25'),
                  (label: '50%', key: 'pct_50'),
                  (label: '100%', key: 'pct_100'),
                ],
          onQuickAction: amountLocked || widget.wallet == null
              ? null
              : (key) => _applyQuickPercent(
                  key: key,
                  amountBtcAvailable: widget.wallet!.balance,
                  feeBtc:
                      widget.destination.isExternal &&
                          widget.feeQuote.networkFeeCertainty ==
                              NetworkFeeCertainty.known
                      ? widget.feeQuote.networkFeeBtc
                      : 0,
                ),
          bottomAccessory: amountLocked
              ? null
              : AmountCalculatorToolbar(onOperator: _onCalculatorOp),
          ctaLabel: context.tr.continueButton,
          ctaEnabled: canContinue,
          isBusy: widget.isLoading || widget.feeQuote.isLoading,
          onCta: widget.onContinue,
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
    final spendable = (amountBtcAvailable - feeBtc).clamp(
      0.0,
      amountBtcAvailable,
    );
    final targetBtc = spendable * fraction;
    if (targetBtc <= 0) {
      _onAmountTextChanged('0');
      return;
    }

    if (widget.selectedCurrency == Currency.btc) {
      _onAmountTextChanged(_trimZeros(targetBtc.toStringAsFixed(8)));
      return;
    }

    final fiat = MoneyDisplay.convertFromBtcAmount(
      btcAmount: targetBtc,
      currency: widget.selectedCurrency,
      btcUsd: widget.btcUsd,
      btcEur: widget.btcEur,
      btcBrl: widget.btcBrl,
    );
    _onAmountTextChanged(_trimZeros(fiat.toStringAsFixed(2)));
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

  const _FeeTierBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SendFeeTierBar(selected: selected, onSelected: onSelected);
  }
}

/// Shared fee-speed chips (amount step + locked-amount confirmation).
class SendFeeTierBar extends StatelessWidget {
  final NetworkFeeTier selected;
  final ValueChanged<NetworkFeeTier> onSelected;

  const SendFeeTierBar({
    super.key,
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
                    ? Theme.of(context).colorScheme.onSurface
                    : SendFlowTheme.of(context).surfaceHigh,
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
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: AppTypography.w510,
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
    if (!feeQuote.hasAmount) return SizedBox.shrink();
    final tokens = SendFlowTheme.of(context);
    final showPlatformFee =
        destination.isExternal &&
        (feeQuote.platformFeeBtc > 0 || feeQuote.isLoading);
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
                context.tr.sendSpeedTitle,
                style: AppTypography.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: tokens.spaceXs + 2),
              Tooltip(
                message: 'Taxas menores demoram um pouco mais para confirmar.',
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  KeroseneIcons.help,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd - 4),
          _FeeTierBar(selected: feeTier, onSelected: onFeeTierChanged!),
          if (showFeeCard) SizedBox(height: tokens.spaceLg),
        ],
        if (showFeeCard)
          SendFlowCard(
            child: Column(
              children: [
                _AnimatedBreakdownRow(
                  label: 'Quem recebe',
                  amountBtc: feeQuote.receiverAmountBtc,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
                if (showPlatformFee) ...[
                  SizedBox(height: tokens.spaceMd - 4),
                  _AnimatedBreakdownRow(
                    label: 'Taxa Kerosene',
                    amountBtc: feeQuote.platformFeeBtc,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    isLoading:
                        feeQuote.isLoading ||
                        (destination.isOnChain &&
                            feeQuote.networkFeeCertainty ==
                                NetworkFeeCertainty.loading),
                    pendingLabel:
                        destination.isLightning &&
                            feeQuote.networkFeeCertainty ==
                                NetworkFeeCertainty.unknownUntilPay
                        ? 'Definida na hora'
                        : null,
                  ),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spaceMd - 4),
                  child: Divider(
                    color: Theme.of(context).dividerColor,
                    height: 1,
                  ),
                ),
                _AnimatedBreakdownRow(
                  label: 'Sai da sua conta',
                  amountBtc: feeQuote.totalDebitedBtc,
                  textColor: Theme.of(context).colorScheme.onSurface,
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
    final valueStyle = tokens.amountBody(color: textColor, emphasize: isTotal);

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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else if (pendingLabel != null)
          Text(pendingLabel!, style: valueStyle)
        else
          TweenAnimationBuilder<double>(
            duration: KeroseneMotion.sendAmountExpanded,
            curve: KeroseneMotion.standard,
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
