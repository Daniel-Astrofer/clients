import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/widgets/transaction_value_entry_surface.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';

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
    final lang = Localizations.localeOf(context).languageCode;
    return ValueListenableBuilder<String>(
      valueListenable: amount,
      builder: (context, amountValue, child) {
        final amountBtc = resolveAmountBtc(amountValue);
        final amountLocked = hasPaymentLink || lockedAmountBtc > 0;
        final secondaryLabel = selectedCurrency == Currency.btc
            ? formatFiatReference(
                btcAmount: amountBtc,
                btcUsd: btcUsd,
                btcEur: btcEur,
                btcBrl: btcBrl,
              )
            : '≈ ${MoneyDisplay.formatCompact(
                amount: amountBtc,
                currency: Currency.btc,
                maxDecimalPlaces: 8,
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

        final feeLabel = _feeLabel(lang);
        final warningLabel = insufficientBalance
            ? 'Saldo insuficiente'
            : (quoteExpired
                ? switch (lang) {
                    'en' => 'Fee quote expired — updating…',
                    'es' => 'Cotización de tarifa expirada — actualizando…',
                    _ => 'Cotação de taxa expirada — atualizando…',
                  }
                : null);

        return TransactionValueEntrySurface(
          onBack: onBack,
          amountInput: amountValue,
          unitLabel: MoneyDisplay.tickerSymbolFor(selectedCurrency),
          currency: selectedCurrency,
          fiatReference: secondaryLabel,
          configuration: destination.isOnChain && onFeeTierChanged != null
              ? _FeeTierBar(
                  selected: feeTier,
                  onSelected: onFeeTierChanged!,
                  languageCode: lang,
                )
              : null,
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
                ),
          feeLabel: feeLabel,
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

  String? _feeLabel(String lang) {
    if (destination.isLightning) {
      if (feeQuote.networkFeeCertainty ==
          NetworkFeeCertainty.unknownUntilPay) {
        return switch (lang) {
          'en' => 'Network fee estimated at payment',
          'es' => 'Tarifa de red estimada al pagar',
          _ => 'Taxa de rede estimada no pagamento',
        };
      }
    }
    if (!destination.isOnChain) return null;
    if (feeQuote.isLoading ||
        feeQuote.networkFeeCertainty == NetworkFeeCertainty.loading) {
      return switch (lang) {
        'en' => 'Calculating fee…',
        'es' => 'Calculando tarifa…',
        _ => 'Calculando taxa…',
      };
    }
    if (!feeQuote.isReady && feeQuote.error != null) {
      return switch (lang) {
        'en' => 'Fee unavailable',
        'es' => 'Tarifa no disponible',
        _ => 'Taxa indisponível',
      };
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
      lang,
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
  final String languageCode;

  const _FeeTierBar({
    required this.selected,
    required this.onSelected,
    required this.languageCode,
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
                  onTap: () => onSelected(tier),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      FeeTierSelection.tierLabel(tier, languageCode),
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
