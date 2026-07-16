import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/tor_loading_dots.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/flow/movement_flow_coordinator.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/widgets/transaction_value_entry_surface.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/flow/receive_nfc_availability_provider.dart';
import 'package:kerosene/features/movement/screens/receive_method.dart';
import 'package:kerosene/features/movement/screens/receive_nfc_flow_screen.dart';
import 'package:kerosene/features/movement/screens/receive_request_flow_screen.dart';

class MovementAmountScreen extends ConsumerStatefulWidget {
  final Wallet wallet;
  final ReceiveAmountMethod method;
  final bool onChainWallet;
  final NfcPaymentRequestWriter? nfcWriter;

  const MovementAmountScreen({
    super.key,
    required this.wallet,
    required this.method,
    required this.onChainWallet,
    this.nfcWriter,
  });

  @override
  ConsumerState<MovementAmountScreen> createState() =>
      _MovementAmountScreenState();
}

class _MovementAmountScreenState extends ConsumerState<MovementAmountScreen> {
  bool _isContinuing = false;
  Currency _selectedCurrency = Currency.btc;

  Future<void> _continue() async {
    if (_isContinuing) return;
    HapticFeedback.mediumImpact();
    final flowState = ref.read(movementFlowCoordinatorProvider);
    final amountBtc = _currentAmountBtc(flowState);
    if (widget.method == ReceiveAmountMethod.nfc) {
      final canUseNfc = await ref.read(receiveNfcCompatibilityProvider.future);
      if (!canUseNfc) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
        return;
      }
    }

    setState(() => _isContinuing = true);
    try {
      final paymentLink = await _createPaymentLinkIfNeeded(
        amountBtc: amountBtc,
        expiresInMinutes: flowState.paymentLinkExpiresInMinutes,
      );
      if (!mounted) return;

      if (widget.method == ReceiveAmountMethod.nfc) {
        if (paymentLink == null || paymentLink.id.trim().isEmpty) {
          throw FormatException(ReceiveMoneyCopy.nfcIdMissing(context));
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => ReceiveNfcFlowScreen(
              wallet: widget.wallet,
              onChainWallet: widget.onChainWallet,
              amountBtc: amountBtc,
              paymentRequestUri:
                  QrPaymentParser.encodePaymentLink(paymentLink.id),
              paymentRail: paymentLink.paymentRail,
              startNfcWrite: widget.nfcWriter,
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => ReceiveRequestFlowScreen(
            wallet: widget.wallet,
            method: widget.method,
            onChainWallet: widget.onChainWallet,
            amountBtc: amountBtc,
            initialPaymentLink: paymentLink,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      SnackbarHelper.showError(
        ErrorTranslator.translate(context.tr, error.toString()),
      );
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  Future<PaymentLink?> _createPaymentLinkIfNeeded({
    required double amountBtc,
    required int expiresInMinutes,
  }) async {
    // All receive methods that need a shareable request create a link.
    // P2P uses INTERNAL rail so the request is trackable (was empty before).
    if (widget.method != ReceiveAmountMethod.paymentLink &&
        widget.method != ReceiveAmountMethod.qrCode &&
        widget.method != ReceiveAmountMethod.nfc &&
        widget.method != ReceiveAmountMethod.p2p) {
      return null;
    }

    final paymentLink =
        await ref.read(transactionRepositoryProvider).createPaymentLink(
      amount: amountBtc,
      description: ReceiveMoneyCopy.paymentLinkDescription(
        context,
        widget.wallet.name,
      ),
      expiresInMinutes: expiresInMinutes,
      visibility: 'PRIVATE',
      confirmationMode: 'USER_ACTION_REQUIRED',
      amountLocked: true,
      referenceLabel: widget.wallet.name,
      metadata: {
        'walletId': widget.wallet.id,
        'walletName': widget.wallet.name,
        'rail': _paymentRequestRail(),
        'method': widget.method.name,
        'source': 'receive_flow',
      },
    );
    ref.invalidate(paymentLinksProvider);
    ref.invalidate(transactionHistoryProvider);
    return paymentLink;
  }

  String _paymentRequestRail() {
    switch (widget.method) {
      case ReceiveAmountMethod.p2p:
        return 'INTERNAL';
      case ReceiveAmountMethod.nfc:
        return widget.onChainWallet ? 'ONCHAIN' : 'INTERNAL';
      case ReceiveAmountMethod.qrCode:
      case ReceiveAmountMethod.paymentLink:
        return 'ONCHAIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.method == ReceiveAmountMethod.nfc) {
      final nfcCompatibility = ref.watch(receiveNfcCompatibilityProvider);
      final compatible = nfcCompatibility.asData?.value;
      if (compatible != true) {
        if (compatible == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).maybePop();
            }
          });
        }
        return const Center(child: TorLoadingDots());
      }
    }

    final flowState = ref.watch(movementFlowCoordinatorProvider);
    final money = ref.watch(moneyFormatConfigProvider);
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final amountBtc = _amountBtcFromInput(
      amountInput: flowState.amountInput,
      currency: _selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
    final secondaryLabel = _selectedCurrency == Currency.btc
        ? _formatFiatReference(
            btcAmount: amountBtc,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
            fiatCurrency: money.currency == Currency.btc
                ? Currency.brl
                : money.currency,
            appLocale: money.locale,
          )
        : '≈ ${MoneyDisplay.formatCompact(
            amount: amountBtc,
            currency: Currency.btc,
            maxDecimalPlaces: 8,
            appLocale: money.locale,
          )}';

    final title = ReceiveMoneyCopy.amountTitle(context, widget.method);
    final intoWallet =
        ReceiveMoneyCopy.amountIntoWallet(context, widget.wallet.name);

    return Scaffold(
      backgroundColor: KeroseneBrandTokens.background,
      body: TransactionValueEntrySurface(
        onBack: () => Navigator.of(context).maybePop(),
        title: title,
        subtitle: intoWallet.isEmpty ? widget.wallet.name : intoWallet,
        amountInput: flowState.amountInput,
        unitLabel: MoneyDisplay.tickerSymbolFor(_selectedCurrency),
        currency: _selectedCurrency,
        fiatReference: secondaryLabel,
        configuration: _configuration(flowState),
        showKeypad: true,
        onKeyTap: _onKey,
        onCurrencyTap: _toggleAmountCurrency,
        availableLabel: MoneyDisplay.formatCompact(
          amount: widget.wallet.balance,
          currency: Currency.btc,
          appLocale: money.locale,
          maxDecimalPlaces: 8,
        ),
        ctaLabel: widget.method == ReceiveAmountMethod.paymentLink
            ? context.tr.receiveGenAction
            : context.tr.continueButton,
        ctaEnabled: amountBtc > 0 && !_isContinuing,
        isBusy: _isContinuing,
        onCta: _continue,
      ),
    );
  }

  void _onKey(String key) {
    final current = ref.read(movementFlowCoordinatorProvider).amountInput;
    final next = MoneyDisplay.applyKeypadInput(
      currentValue: current,
      key: key,
      currency: _selectedCurrency,
      maxLength: _selectedCurrency == Currency.btc ? 16 : 14,
    );
    ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput(next);
  }

  double _currentAmountBtc(MovementFlowState flowState) {
    return _amountBtcFromInput(
      amountInput: flowState.amountInput,
      currency: _selectedCurrency,
      btcUsd: ref.read(latestBtcPriceProvider),
      btcEur: ref.read(btcEurPriceProvider),
      btcBrl: ref.read(btcBrlPriceProvider),
    );
  }

  double _amountBtcFromInput({
    required String amountInput,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
  }) {
    return MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(amountInput),
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
  }

  void _toggleAmountCurrency() {
    final flowState = ref.read(movementFlowCoordinatorProvider);
    final btcUsd = ref.read(latestBtcPriceProvider);
    final btcEur = ref.read(btcEurPriceProvider);
    final btcBrl = ref.read(btcBrlPriceProvider);
    final amountBtc = _amountBtcFromInput(
      amountInput: flowState.amountInput,
      currency: _selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
    final nextCurrency =
        _selectedCurrency == Currency.btc
            ? (ref.read(moneyFormatConfigProvider).currency == Currency.btc
                ? Currency.brl
                : ref.read(moneyFormatConfigProvider).currency)
            : Currency.btc;
    final nextAmount = nextCurrency == Currency.btc
        ? amountBtc
        : MoneyDisplay.convertFromBtcAmount(
            btcAmount: amountBtc,
            currency: nextCurrency,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
          );

    setState(() => _selectedCurrency = nextCurrency);
    // Natural display string — avoid zero-padded cent buffers.
    final raw = nextAmount <= 0
        ? '0'
        : nextCurrency == Currency.btc
            ? _trimTrailingZeros(nextAmount.toStringAsFixed(8))
            : _trimTrailingZeros(nextAmount.toStringAsFixed(2));
    ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput(raw);
  }

  String _trimTrailingZeros(String value) {
    if (!value.contains('.')) return value;
    return value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Widget? _configuration(MovementFlowState flowState) {
    final rail = ReceiveMoneyCopy.railLabel(
      context,
      widget.method,
      onChainWallet: widget.onChainWallet,
    );
    final railChip = Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: KeroseneBrandTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: KeroseneBrandTokens.border),
        ),
        child: Text(
          rail,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (widget.method != ReceiveAmountMethod.paymentLink) {
      return railChip;
    }

    final options = [
      (minutes: 15, label: context.tr.receive15Min),
      (minutes: 60, label: context.tr.receive1Hour),
      (minutes: 1440, label: context.tr.receive24Hours),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        railChip,
        const SizedBox(height: 18),
        Text(
          context.tr.receiveExpirationLabel,
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final option in options) _expirationButton(flowState, option),
          ],
        ),
      ],
    );
  }

  Widget _expirationButton(
    MovementFlowState flowState,
    ({String label, int minutes}) option,
  ) {
    final selected = flowState.paymentLinkExpiresInMinutes == option.minutes;
    return TextButton(
      onPressed: () => ref
          .read(movementFlowCoordinatorProvider.notifier)
          .selectPaymentLinkExpiration(option.minutes),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? KeroseneBrandTokens.background
            : KeroseneBrandTokens.textPrimary,
        backgroundColor: selected
            ? KeroseneBrandTokens.textPrimary
            : KeroseneBrandTokens.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected
                ? KeroseneBrandTokens.textPrimary
                : KeroseneBrandTokens.border,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(option.label),
    );
  }

  String _formatFiatReference({
    required double btcAmount,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    required Currency fiatCurrency,
    Locale? appLocale,
  }) {
    if (btcAmount <= 0) {
      return '≈ ${MoneyDisplay.format(
        amount: 0,
        currency: fiatCurrency,
        appLocale: appLocale,
      )}';
    }
    return '≈ ${MoneyDisplay.formatAmountFromBtc(
      btcAmount: btcAmount,
      currency: fiatCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: appLocale,
    )}';
  }
}
