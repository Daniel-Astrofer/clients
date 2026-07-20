// ignore_for_file: unused_import, unused_element, use_key_in_widget_constructors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/security/secure_screen_guard.dart';
import 'package:kerosene/core/security/rasp_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/core/presentation/widgets/tor_loading_dots.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/features/movement/domain/payment_intent.dart';
import 'package:kerosene/features/movement/domain/payment_intent_parser.dart';
import 'package:kerosene/features/movement/domain/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/domain/payment_security_guards.dart';
import 'package:kerosene/features/movement/widgets/destination_capture_sheet.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/movement/domain/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/domain/entities/withdraw_fee_quote_calculation.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/flow/movement_flow_coordinator.dart';
import 'package:kerosene/app/providers/kfe_receiving_capabilities_provider.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';

import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_key_vault.dart';
import 'package:kerosene/features/movement/widgets/send_money_components.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';

import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/features/movement/screens/send_payment_confirmation_flow.dart';
import 'package:kerosene/features/movement/screens/send_payment_review_helpers.dart';
import 'package:kerosene/features/movement/screens/send_payment_request_flow.dart';
import 'package:kerosene/features/movement/screens/send_security_profile_resolver.dart';
import 'package:kerosene/features/movement/screens/send_wallet_resolver.dart';


import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/screens/send_destination_analyzer.dart';
import 'package:kerosene/features/movement/screens/send_amount_step.dart';
import 'package:kerosene/features/movement/screens/send_destination_step.dart';
import 'package:kerosene/features/movement/widgets/internal_recent_avatar.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';
import 'package:kerosene/features/movement/flow/send_money_flow_notifier.dart';

class SendMoneyScreen extends ConsumerStatefulWidget {
  final String? walletId;
  final String? initialAddress;
  final double? initialAmountBtc;

  const SendMoneyScreen({
    super.key,
    this.walletId,
    this.initialAddress,
    this.initialAmountBtc,
  });

  @override
  ConsumerState<SendMoneyScreen> createState() => SendMoneyScreenState();
}

class SendMoneyScreenState extends ConsumerState<SendMoneyScreen>
    with FinancialSurfaceMixin {
  static const Color internalBlack = KeroseneBrandTokens.background;
  static const Color internalSurface = KeroseneBrandTokens.surface;
  static const Color internalSurfaceHigh = KeroseneBrandTokens.surfaceHigh;
  static const Color internalBorder = KeroseneBrandTokens.border;
  static const Color internalText = KeroseneBrandTokens.textPrimary;
  static const Color internalMutedText = KeroseneBrandTokens.textMuted;
  static const Color internalOutline = KeroseneBrandTokens.borderStrong;
  String? _pendingPaymentLinkId;
  NetworkFeeTier get _selectedFeeTier => ref.read(sendMoneyFlowProvider).value?.selectedFeeTier ?? NetworkFeeTier.standard;
  set _selectedFeeTier(NetworkFeeTier value) => ref.read(sendMoneyFlowProvider.notifier).setFeeTier(value);
  SendDestinationType? _lastHapticDestinationType;
  String get _lockedRecipientAddress => ref.read(sendMoneyFlowProvider).value?.lockedRecipientAddress ?? '';
  set _lockedRecipientAddress(String value) => ref.read(sendMoneyFlowProvider.notifier).updateDestination(
    ref.read(sendMoneyFlowProvider).value?.destinationAnalysis ?? null,
    lockedAddress: value,
  );
  String? _recentDestinationAddressForSave;
  double get _lockedAmountBtc => ref.read(sendMoneyFlowProvider).value?.lockedAmountBtc ?? 0.0;
  set _lockedAmountBtc(double value) => ref.read(sendMoneyFlowProvider.notifier).updateDestination(
    ref.read(sendMoneyFlowProvider).value?.destinationAnalysis ?? null,
    lockedAmount: value,
  );
  String? get _lockedRecipientLabel => ref.read(sendMoneyFlowProvider).value?.lockedRecipientLabel;
  set _lockedRecipientLabel(String? value) => ref.read(sendMoneyFlowProvider.notifier).updateDestination(
    ref.read(sendMoneyFlowProvider).value?.destinationAnalysis ?? null,
    lockedLabel: value,
  );
  Wallet? get _selectedWallet => ref.read(sendMoneyFlowProvider).value?.selectedWallet;
  set _selectedWallet(Wallet? value) {
    if (value != null) ref.read(sendMoneyFlowProvider.notifier).selectWallet(value);
  }
  bool _destinationResolutionBusy = false;
  int _destinationEditVersion = 0;

  /// Live capabilities resolve for username destinations (PR3).
  ResolvedPaymentIntent? _liveResolvedIntent;
  PaymentRail? _userSelectedRail;
  bool _liveResolving = false;
  String? _liveResolveError;
  Timer? _liveResolveTimer;
  int _liveResolveToken = 0;

  final _receiverController = TextEditingController();

  final ValueNotifier<String> _amount = ValueNotifier<String>('0');
  late Currency _selectedCurrency;

  late final PageController _pageController;
  late final RaspGuard _raspGuard;

  int get _currentStep => ref.read(sendMoneyFlowProvider).value?.currentStep ?? 0;

  bool get _hasPreselectedWallet =>
      widget.walletId != null && widget.walletId!.trim().isNotEmpty;

  int get _firstStep => 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _raspGuard = RaspGuard.instance;
    _raspGuard.start();
    _selectedCurrency = Currency.btc;
    if (widget.initialAmountBtc != null) {
      _lockedAmountBtc = widget.initialAmountBtc!;
      _amount.value = widget.initialAmountBtc!
          .toStringAsFixed(8)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletState = ref.read(walletProvider);
      if (walletState is WalletInitial || walletState is WalletError) {
        unawaited(ref.read(walletProvider.notifier).refresh());
      }
      if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
        unawaited(_parsePaymentRequest(widget.initialAddress!));
      }
      // Cold stays in the same wizard (PR6) — local seed signs at confirm.
    });
  }

  @override
  void dispose() {
    _liveResolveTimer?.cancel();
    _receiverController.dispose();
    _amount.dispose();
    _pageController.dispose();
    _raspGuard.stop();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    if (_lockedAmountBtc > 0) return; // Prevent changing locked amount

    _amount.value = value.trim().isEmpty ? '0' : value;
  }

  void _toggleAmountCurrency() {
    if (_lockedAmountBtc > 0 || _pendingPaymentLinkId != null) return;

    final btcUsd = ref.read(latestBtcPriceProvider);
    final btcEur = ref.read(btcEurPriceProvider);
    final btcBrl = ref.read(btcBrlPriceProvider);
    final amountBtc = _currentAmountBtc(
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      amountVal: _amount.value,
    );
    // Toggle BTC ↔ preferred fiat (from app display prefs), not always BRL.
    final prefsCurrency = ref.read(moneyFormatConfigProvider).currency;
    final preferredFiat =
        prefsCurrency == Currency.btc ? Currency.brl : prefsCurrency;
    final nextCurrency =
        _selectedCurrency == Currency.btc ? preferredFiat : Currency.btc;
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
    // Natural keypad string (no fixed trailing zero buffer).
    if (nextAmount <= 0) {
      _amount.value = '0';
    } else if (nextCurrency == Currency.btc) {
      _amount.value = nextAmount
          .toStringAsFixed(8)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    } else {
      _amount.value = nextAmount
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
  }

  double _amountAsDouble(String amountVal) =>
      MoneyDisplay.parseEditableInput(amountVal);

  double _currentAmountBtc({
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    required String amountVal,
  }) {
    if (_lockedAmountBtc > 0) {
      return _lockedAmountBtc;
    }
    return MoneyDisplay.convertToBtcAmount(
      amount: _amountAsDouble(amountVal),
      currency: _selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStepWatch = ref.watch(sendMoneyFlowProvider).value?.currentStep ?? 0;
    ref.watch(balanceWebSocketServiceProvider);
    var isLoading = false;
    if (currentStepWatch == 2) {
      final isSending = ref.watch(
        sendTransactionProvider.select((state) => state.isLoading),
      );
      final isPayingLink = ref.watch(
        paymentLinkNotifierProvider.select((state) => state.isLoading),
      );
      isLoading = isSending || isPayingLink;
    }
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final amountBtc = _currentAmountBtc(
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      amountVal: _amount.value,
    );
    final walletState = ref.watch(walletProvider);

    if (currentStepWatch != 0 &&
        (walletState is WalletInitial || walletState is WalletLoading)) {
      return const Center(child: TorLoadingDots());
    }

    final currentWallet = _resolveWallet(walletState);
    final destinationAnalysis = _currentDestinationAnalysis();
    final isOnline = ref.watch(networkStatusProvider);
    final AsyncValue<FeeEstimate>? feeEstimateAsync =
        destinationAnalysis.isOnChain && amountBtc > 0
            ? ref.watch(feeEstimateProvider(amountBtc))
            : null;
    final feeQuote = _resolveFeeQuote(
      wallet: currentWallet,
      destination: destinationAnalysis,
      amountBtc: amountBtc,
      feeEstimateAsync: feeEstimateAsync,
    );

    _maybeHapticDestination(destinationAnalysis);

    return SecureScreenScope(
      child: PopScope(
        canPop: _currentStep == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
          backgroundColor: internalBlack,
          resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            if (!isOnline) _OfflineSendBanner(onRetry: _retryOnline),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  RepaintBoundary(
                    child: SafeArea(child: _buildDestinationStep(context)),
                  ),
                  RepaintBoundary(
                    child: SafeArea(
                      child: _buildAmountStep(
                        context,
                        btcUsd: btcUsd,
                        btcEur: btcEur,
                        btcBrl: btcBrl,
                        amountBtc: amountBtc,
                        wallet: currentWallet,
                        destination: destinationAnalysis,
                        feeQuote: feeQuote,
                        isLoading: isLoading,
                        isOnline: isOnline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybeHapticDestination(SendDestinationAnalysis analysis) {
    if (!analysis.isValid) {
      _lastHapticDestinationType = analysis.type;
      return;
    }
    if (_lastHapticDestinationType == analysis.type) return;
    _lastHapticDestinationType = analysis.type;
    // Schedule outside build to avoid side effects mid-frame issues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.selectionClick();
    });
  }

  Future<void> _retryOnline() async {
    HapticFeedback.lightImpact();
    await ref.read(networkStatusProvider.notifier).checkConnection();
  }

  bool _ensureOnline() {
    final online = ref.read(networkStatusProvider);
    if (online) return true;
    SnackbarHelper.showError(SendMoneyCopy.offlineBlocked(context));
    return false;
  }

  void _handleBack() {
    if (_currentStep > 0) {
      int previousStep = _currentStep - 1;

      _pageController.animateToPage(
        previousStep,
        duration: KeroseneMotion.medium,
        curve: KeroseneMotion.standard,
      );
      ref.read(sendMoneyFlowProvider.notifier).setStep(previousStep);
      return;
    }

    Navigator.of(context).maybePop();
  }

  Widget _buildInternalTopBar(BuildContext context) {
    return InternalTopBar(
      onBack: _handleBack,
      textColor: internalText,
    );
  }

  Widget _buildInternalPrimaryButton({
    required String label,
    IconData? icon,
    required bool enabled,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InternalPrimaryButton(
      label: label,
      icon: icon,
      enabled: enabled,
      onTap: onTap,
      isLoading: isLoading,
      backgroundColor: internalText,
      foregroundColor: internalBlack,
    );
  }

  Future<void> _handleContinue() async {
    if (!_ensureOnline()) return;
    final insufficientBalanceMessage =
        SendMoneyCopy.insufficientBalance(context);
    final walletState = ref.read(walletProvider);
    final currentWallet = _resolveWallet(walletState);
    if (currentWallet == null) {
      SnackbarHelper.showError(SendMoneyCopy.walletLoadFailed(context));
      return;
    }
    final btcUsd = ref.read(latestBtcPriceProvider);
    final btcEur = ref.read(btcEurPriceProvider);
    final btcBrl = ref.read(btcBrlPriceProvider);
    var amountBtc = _currentAmountBtc(
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      amountVal: _amount.value,
    );
    var destination = _currentDestinationAnalysis();

    HapticFeedback.mediumImpact();

    if (!destination.isValid) {
      SnackbarHelper.showError(
        destination.isEmpty
            ? context.tr.sendMoneyMissingDestination
            : SendMoneyCopy.unrecognizedDestination(context),
      );
      return;
    }

    // Cold: only on-chain destinations — block early (before amount/auth).
    if (_isColdSource(currentWallet)) {
      if (destination.isPaymentLink) {
        SnackbarHelper.showError(SendMoneyCopy.coldNoPaymentLink(context));
        return;
      }
      if (destination.isInternal) {
        SnackbarHelper.showError(SendMoneyCopy.coldNoInternal(context));
        return;
      }
      if (destination.isLightning) {
        SnackbarHelper.showError(SendMoneyCopy.coldNoLightning(context));
        return;
      }
      if (!destination.isOnChain) {
        SnackbarHelper.showError(SendMoneyCopy.coldOnlyOnchain(context));
        return;
      }
    }

    if (destination.isPaymentLink && _pendingPaymentLinkId == null) {
      final linkId = destination.paymentLinkId;
      if (linkId == null || linkId.isEmpty) {
        SnackbarHelper.showError(context.tr.sendMoneyInvalidPaymentRequest);
        return;
      }
      final loaded = await _fetchPaymentLinkDetails(linkId);
      if (!loaded) return;
      if (!mounted) return;
      amountBtc = _currentAmountBtc(
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
        amountVal: _amount.value,
      );
      destination = _currentDestinationAnalysis();
    }

    if (mounted) {
      setState(() => _destinationResolutionBusy = true);
    }
    final resolvedDestination = await _resolveDestinationForKfe(destination);
    if (!mounted) return;
    if (resolvedDestination == null) {
      setState(() => _destinationResolutionBusy = false);
      return;
    }
    destination = resolvedDestination;

    final ownColdOnchain = _ownColdWalletOnchainDestination(
      walletState,
      destination,
    );
    if (ownColdOnchain != null) {
      // Internal UUID of own cold wallet → fund via on-chain address instead.
      destination = ownColdOnchain;
    } else if (_isSameSourceWalletDestination(
      currentWallet,
      destination,
    )) {
      // Only block sending to the *same* source wallet (true self-loop).
      // INTERNAL → CUSTODIAL_ONCHAIN (same user, different wallets) is allowed.
      setState(() => _destinationResolutionBusy = false);
      SnackbarHelper.showError(context.tr.errLedgerPaymentRequestSelfPay);
      return;
    }

    if (amountBtc <= 0) {
      setState(() => _destinationResolutionBusy = false);
      SnackbarHelper.showError(context.tr.errorAmountRequired);
      return;
    }

    var feeQuote = await _resolveSubmitFeeQuote(
      wallet: currentWallet,
      destination: destination,
      amountBtc: amountBtc,
    );
    if (feeQuote == null) {
      setState(() => _destinationResolutionBusy = false);
      return;
    }

    // Fail-closed: never submit with a stale on-chain quote.
    if (destination.isOnChain && feeQuote.isQuoteExpired) {
      ref.invalidate(feeEstimateProvider(amountBtc));
      feeQuote = await _resolveSubmitFeeQuote(
        wallet: currentWallet,
        destination: destination,
        amountBtc: amountBtc,
      );
      if (feeQuote == null || feeQuote.isQuoteExpired) {
        setState(() => _destinationResolutionBusy = false);
        SnackbarHelper.showError(
          SendMoneyCopy.networkFeeUnavailable(context),
        );
        return;
      }
    }

    if (destination.isOnChain && !feeQuote.isReadyForOnchainSubmit) {
      setState(() => _destinationResolutionBusy = false);
      SnackbarHelper.showError(
        SendMoneyCopy.networkFeeUnavailable(context),
      );
      return;
    }

    final totalDebited =
        destination.isExternal ? feeQuote.totalDebitedBtc : amountBtc;

    if (!WithdrawFeeQuoteCalculation.hasSufficientBalance(
      availableBtc: currentWallet.balance,
      totalDebitedBtc: totalDebited,
    )) {
      setState(() => _destinationResolutionBusy = false);
      SnackbarHelper.showError(insufficientBalanceMessage);
      return;
    }

    await _openPaymentConfirmation(
      wallet: currentWallet,
      destination: destination,
      amount: destination.isExternal ? feeQuote.receiverAmountBtc : amountBtc,
      requestedAmount: amountBtc,
      feeQuote: feeQuote,
      toAddress: destination.normalizedValue,
    );
    if (mounted) {
      setState(() => _destinationResolutionBusy = false);
    }
  }

  SendFeeQuote _resolveFeeQuote({
    required Wallet? wallet,
    required SendDestinationAnalysis destination,
    required double amountBtc,
    required AsyncValue<FeeEstimate>? feeEstimateAsync,
  }) {
    if (!destination.isExternal || wallet == null || amountBtc <= 0) {
      return SendFeeQuote(
        requestedAmountBtc: amountBtc,
        receiverAmountBtc: amountBtc,
        platformFeeRate: wallet?.withdrawalFeeRate ?? 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: amountBtc,
        feeTier: _selectedFeeTier,
      );
    }

    // Cold has no Kerosene platform fee — only chain network fee.
    final platformFeeRate =
        _isColdSource(wallet) ? 0.0 : wallet.withdrawalFeeRate;
    if (destination.isLightning) {
      if (_isColdSource(wallet)) {
        return SendFeeQuote(
          requestedAmountBtc: amountBtc,
          receiverAmountBtc: amountBtc,
          platformFeeRate: 0,
          platformFeeBtc: 0,
          networkFeeBtc: 0,
          totalDebitedBtc: amountBtc,
          error: 'cold_no_lightning',
          feeTier: _selectedFeeTier,
        );
      }
      // Honest LN: do not invent a routing fee constant as if it were exact.
      return _buildLightningFeeQuote(
        amountBtc: amountBtc,
        platformFeeRate: platformFeeRate,
      );
    }

    if (feeEstimateAsync == null) {
      return SendFeeQuote(
        requestedAmountBtc: amountBtc,
        receiverAmountBtc: amountBtc,
        platformFeeRate: platformFeeRate,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: amountBtc,
        isLoading: true,
        feeTier: _selectedFeeTier,
        networkFeeCertainty: NetworkFeeCertainty.loading,
      );
    }

    FeeEstimate? resolvedFee;
    bool isLoading = false;
    Object? error;

    feeEstimateAsync.when(
      data: (fee) => resolvedFee = fee,
      loading: () => isLoading = true,
      error: (err, _) => error = err,
    );

    if (isLoading || error != null) {
      return SendFeeQuote(
        requestedAmountBtc: amountBtc,
        receiverAmountBtc: amountBtc,
        platformFeeRate: platformFeeRate,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: amountBtc,
        isLoading: isLoading,
        error: error,
        feeTier: _selectedFeeTier,
        networkFeeCertainty: isLoading
            ? NetworkFeeCertainty.loading
            : NetworkFeeCertainty.known,
      );
    }

    if (resolvedFee?.serverPriced == true) {
      return _buildOnchainFeeQuote(
        amountBtc: amountBtc,
        fee: resolvedFee!,
        tier: _selectedFeeTier,
      );
    }

    final tierPick = FeeTierSelection.fromEstimate(
      resolvedFee!,
      tier: _selectedFeeTier,
    );
    return _buildExternalFeeQuote(
      amountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: tierPick.networkFeeBtc,
      feeRateSatPerByte: tierPick.feeRateSatPerByte,
      estimatedSettlementSeconds: tierPick.estimatedSettlementSeconds,
      feeTargetBlocks: tierPick.feeTargetBlocks,
      feeSource: resolvedFee!.feeSource,
      quoteExpiresAt: resolvedFee!.quoteExpiresAt,
    );
  }

  Future<SendFeeQuote?> _resolveSubmitFeeQuote({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amountBtc,
  }) async {
    final networkFeeUnavailableMessage =
        SendMoneyCopy.networkFeeUnavailable(context);
    if (!destination.isExternal) {
      return SendFeeQuote(
        requestedAmountBtc: amountBtc,
        receiverAmountBtc: amountBtc,
        platformFeeRate: 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: amountBtc,
        feeTier: _selectedFeeTier,
      );
    }

    if (destination.isLightning) {
      if (_isColdSource(wallet)) {
        SnackbarHelper.showError(SendMoneyCopy.coldNoLightning(context));
        return null;
      }
      return _buildLightningFeeQuote(
        amountBtc: amountBtc,
        platformFeeRate: wallet.withdrawalFeeRate,
      );
    }

    try {
      final fee = await ref.read(feeEstimateProvider(amountBtc).future);
      if (fee.quoteExpiresAt != null &&
          !DateTime.now().toUtc().isBefore(fee.quoteExpiresAt!.toUtc())) {
        ref.invalidate(feeEstimateProvider(amountBtc));
        final refreshed = await ref.read(feeEstimateProvider(amountBtc).future);
        return _quoteFromFeeEstimate(
          amountBtc: amountBtc,
          wallet: wallet,
          fee: refreshed,
        );
      }
      return _quoteFromFeeEstimate(
        amountBtc: amountBtc,
        wallet: wallet,
        fee: fee,
      );
    } catch (error) {
      SnackbarHelper.showError(networkFeeUnavailableMessage);
      return null;
    }
  }

  SendFeeQuote _quoteFromFeeEstimate({
    required double amountBtc,
    required Wallet wallet,
    required FeeEstimate fee,
  }) {
    if (fee.serverPriced) {
      return _buildOnchainFeeQuote(
        amountBtc: amountBtc,
        fee: fee,
        tier: _selectedFeeTier,
      );
    }
    final tierPick =
        FeeTierSelection.fromEstimate(fee, tier: _selectedFeeTier);
    return _buildExternalFeeQuote(
      amountBtc: amountBtc,
      platformFeeRate: _isColdSource(wallet) ? 0.0 : wallet.withdrawalFeeRate,
      networkFeeBtc: tierPick.networkFeeBtc,
      feeRateSatPerByte: tierPick.feeRateSatPerByte,
      estimatedSettlementSeconds: tierPick.estimatedSettlementSeconds,
      feeTargetBlocks: tierPick.feeTargetBlocks,
      feeSource: fee.feeSource,
      quoteExpiresAt: fee.quoteExpiresAt,
    );
  }

  SendFeeQuote _buildOnchainFeeQuote({
    required double amountBtc,
    required FeeEstimate fee,
    required NetworkFeeTier tier,
  }) {
    final tierPick = FeeTierSelection.fromEstimate(fee, tier: tier);
    // Server-priced quotes currently price the standard tier as totalToSend.
    // When another tier is selected, recompute debit from network fee delta.
    final standardNet = fee.estimatedStandardBtc;
    final tierNet = tierPick.networkFeeBtc;
    final delta = tierNet - standardNet;
    final totalDebited = fee.serverPriced
        ? (fee.totalToSend + delta).clamp(0.0, double.infinity)
        : fee.totalToSend;
    final platformFeeRate =
        amountBtc > 0 ? fee.keroseneFeeBtc / amountBtc : 0.0;
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: fee.amountReceived,
      platformFeeRate: platformFeeRate,
      platformFeeBtc: fee.keroseneFeeBtc,
      networkFeeBtc: tierNet,
      totalDebitedBtc: totalDebited,
      feeRateSatPerByte: tierPick.feeRateSatPerByte,
      estimatedSettlementSeconds: tierPick.estimatedSettlementSeconds,
      feeTargetBlocks: tierPick.feeTargetBlocks,
      feeSource: fee.feeSource,
      quoteExpiresAt: fee.quoteExpiresAt,
      feeTier: tier,
      networkFeeCertainty: NetworkFeeCertainty.known,
    );
  }

  SendFeeQuote _buildLightningFeeQuote({
    required double amountBtc,
    required double platformFeeRate,
  }) {
    final calculation = WithdrawFeeQuoteCalculation.resolve(
      mode: WithdrawFeeMode.senderPays,
      requestedAmountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: 0,
    );
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: calculation.receiverAmountBtc,
      platformFeeRate: calculation.platformFeeRate,
      platformFeeBtc: calculation.platformFeeBtc,
      networkFeeBtc: 0,
      // Debit shown without invented routing fee; network fee settles at pay time.
      totalDebitedBtc: calculation.totalDebitedBtc,
      feeSource: 'lightning_routing_unknown',
      feeTier: _selectedFeeTier,
      networkFeeCertainty: NetworkFeeCertainty.unknownUntilPay,
    );
  }

  SendFeeQuote _buildExternalFeeQuote({
    required double amountBtc,
    required double platformFeeRate,
    required double networkFeeBtc,
    double? feeRateSatPerByte,
    int? estimatedSettlementSeconds,
    int? feeTargetBlocks,
    String? feeSource,
    DateTime? quoteExpiresAt,
  }) {
    final calculation = WithdrawFeeQuoteCalculation.resolve(
      mode: WithdrawFeeMode.senderPays,
      requestedAmountBtc: amountBtc,
      platformFeeRate: platformFeeRate,
      networkFeeBtc: networkFeeBtc,
    );
    return SendFeeQuote(
      requestedAmountBtc: amountBtc,
      receiverAmountBtc: calculation.receiverAmountBtc,
      platformFeeRate: calculation.platformFeeRate,
      platformFeeBtc: calculation.platformFeeBtc,
      networkFeeBtc: calculation.networkFeeBtc,
      totalDebitedBtc: calculation.totalDebitedBtc,
      feeRateSatPerByte: feeRateSatPerByte,
      estimatedSettlementSeconds: estimatedSettlementSeconds,
      feeTargetBlocks: feeTargetBlocks,
      feeSource: feeSource,
      quoteExpiresAt: quoteExpiresAt,
      feeTier: _selectedFeeTier,
      networkFeeCertainty: NetworkFeeCertainty.known,
    );
  }

  Future<AccountSecurityProfile> _resolveSecurityProfile(Wallet wallet) async {
    try {
      return await ref.read(accountSecurityProfileProvider.future);
    } catch (_) {
      return fallbackSendSecurityProfile(wallet.accountSecurity);
    }
  }

  Wallet? _resolveWallet(WalletState walletState) {
    return resolveSendWallet(
      walletState: walletState,
      selectedWallet: _selectedWallet,
      requestedWalletId: widget.walletId,
    );
  }



  bool _isColdSource(Wallet? wallet) =>
      wallet != null && (wallet.isColdWallet || wallet.isSelfCustody);

  Widget _buildDestinationStep(BuildContext context) {
    final recentDestinations = ref
        .watch(recentTransactionDestinationsProvider)
        .toList(growable: false);
    final analysis = _currentDestinationAnalysis();

    return SendDestinationStep(
      receiverController: _receiverController,
      analysis: analysis,
      recentDestinations: recentDestinations,
      isLoading: _destinationResolutionBusy || _liveResolving,
      canWizardBack: _currentStep > _firstStep,
      onLeading: _handleBack,
      onDestinationChanged: () {
        setState(() {
          _destinationEditVersion += 1;
          _destinationResolutionBusy = false;
          _pendingPaymentLinkId = null;
          _lockedRecipientAddress = '';
          _recentDestinationAddressForSave = null;
          _lockedRecipientLabel = null;
          _liveResolvedIntent = null;
          _userSelectedRail = null;
          _liveResolveError = null;
          _liveResolving = false;
          if (widget.initialAmountBtc == null) {
            _lockedAmountBtc = 0;
          }
        });
        _scheduleLiveResolve();
      },
      onScan: _scanInternalDestination,
      onRecentDestinationSelected: _applyRecentInternalDestination,
      resolvedIntent: _liveResolvedIntent,
      isLiveResolving: _liveResolving,
      liveResolveError: _liveResolveError,
      onRailSelected: (rail) {
        setState(() {
          _userSelectedRail = rail;
          final current = _liveResolvedIntent;
          if (current != null) {
            _liveResolvedIntent = ResolvedPaymentIntent(
              intent: current.intent,
              source: current.source,
              selectedRail: rail,
              alternatives: current.alternatives
                  .map(
                    (o) => RailOption(
                      rail: o.rail,
                      title: o.title,
                      subtitle: o.subtitle,
                      recommended: o.rail == rail,
                    ),
                  )
                  .toList(growable: false),
              destWalletId: current.destWalletId,
              destOnchainAddress: current.destOnchainAddress,
              explainWhy: current.explainWhy,
              amountLocked: current.amountLocked,
              blockers: current.blockers,
            );
          }
        });
      },
      onContinue: () {
        final currentDestination = _receiverController.text.trim();
        final currentAnalysis = _currentDestinationAnalysis();
        if (!currentAnalysis.isValid) {
          SnackbarHelper.showError(
            currentDestination.isEmpty
                ? context.tr.sendMoneyMissingDestination
                : SendMoneyCopy.unrecognizedDestination(context),
          );
          return;
        }
        if (_liveResolvedIntent != null &&
            !_liveResolvedIntent!.canContinue) {
          final msg = _liveResolvedIntent!.blockers.isNotEmpty
              ? _liveResolvedIntent!.blockers.first.message
              : context.tr.errReceiverNotReady;
          SnackbarHelper.showError(msg);
          return;
        }
        unawaited(_continueFromDestinationStep(currentAnalysis));
      },
    );
  }

  void _scheduleLiveResolve() {
    _liveResolveTimer?.cancel();
    final intent = const PaymentIntentParser().parse(_receiverController.text);
    if (!shouldLiveResolveInternal(intent)) {
      // Local-only resolve for external destinations (network/self-pay hints).
      final wallet = _selectedWallet ??
          (_resolveWallet(ref.read(walletProvider)));
      final local = PaymentIntentResolver.instance.resolveLocal(
        intent: intent,
        source: sourceCustodyOf(wallet),
        sourceWalletId: wallet?.id,
        sourceWalletAddress: wallet?.address,
        userSelectedRail: _userSelectedRail,
        expectedNetwork: expectedBitcoinNetwork,
      );
      if (!intent.isEmpty && !intent.isInvalid && !intent.isInternal) {
        setState(() {
          _liveResolvedIntent = local;
          _liveResolveError = local.blockers.isNotEmpty
              ? local.blockers.first.message
              : null;
        });
      }
      return;
    }

    setState(() {
      _liveResolving = true;
      _liveResolveError = null;
    });
    final token = ++_liveResolveToken;
    _liveResolveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runLiveResolve(token: token, intent: intent));
    });
  }

  Future<void> _runLiveResolve({
    required int token,
    required PaymentIntent intent,
  }) async {
    final wallet = _selectedWallet ?? _resolveWallet(ref.read(walletProvider));
    final source = sourceCustodyOf(wallet);
    try {
      final capabilities = await ref
          .read(kfeReceivingCapabilitiesServiceProvider)
          .receivingCapabilities(intent.normalizedValue);
      if (!mounted || token != _liveResolveToken) return;
      final resolved =
          PaymentIntentResolver.instance.resolveWithCapabilities(
        intent: intent,
        source: source,
        capabilities: capabilities,
        userSelectedRail: _userSelectedRail,
        sourceWalletId: wallet?.id,
        sourceWalletAddress: wallet?.address,
        expectedNetwork: expectedBitcoinNetwork,
        destOnchainAddress: capabilities.onchainReceiveAddress,
      );
      setState(() {
        _liveResolvedIntent = resolved;
        _liveResolving = false;
        _liveResolveError = resolved.blockers.isNotEmpty
            ? resolved.blockers.first.message
            : null;
      });
    } catch (error) {
      if (!mounted || token != _liveResolveToken) return;
      setState(() {
        _liveResolving = false;
        _liveResolvedIntent = null;
        _liveResolveError =
            ErrorTranslator.translate(context.tr, error.toString());
      });
    }
  }

  Future<void> _continueFromDestinationStep(
    SendDestinationAnalysis analysis,
  ) async {
    if (_destinationResolutionBusy) {
      return;
    }
    if (!_ensureOnline()) return;

    FocusScope.of(context).unfocus();
    final editVersion = _destinationEditVersion;
    var destination = analysis;
    final sourceWallet = _resolveWallet(ref.read(walletProvider));

    setState(() => _destinationResolutionBusy = true);
    try {
      if (!destination.isValid) {
        SnackbarHelper.showError(
          destination.isEmpty
              ? context.tr.sendMoneyMissingDestination
              : SendMoneyCopy.unrecognizedDestination(context),
        );
        return;
      }

      // Cold source: require local seed and on-chain destination only.
      if (_isColdSource(sourceWallet)) {
        final hasSeed =
            await ColdWalletKeyVault.instance.hasSeed(sourceWallet!.id.trim());
        if (!mounted || editVersion != _destinationEditVersion) return;
        if (!hasSeed) {
          SnackbarHelper.showError(SendMoneyCopy.coldSeedMissing(context));
          return;
        }
        if (destination.isPaymentLink || destination.isLightning) {
          SnackbarHelper.showError(SendMoneyCopy.coldOnlyOnchain(context));
          return;
        }
      }

      if (destination.isPaymentLink) {
        final linkId = destination.paymentLinkId;
        if (linkId == null || linkId.isEmpty) {
          SnackbarHelper.showError(context.tr.sendMoneyInvalidPaymentRequest);
          return;
        }
        final loaded = await _fetchPaymentLinkDetails(
          linkId,
          destinationEditVersion: editVersion,
        );
        if (!loaded || !mounted || editVersion != _destinationEditVersion) {
          return;
        }
        destination = _currentDestinationAnalysis();
      } else {
        final resolvedDestination =
            await _resolveDestinationForKfe(destination);
        if (resolvedDestination == null ||
            !mounted ||
            editVersion != _destinationEditVersion) {
          return;
        }
        destination = resolvedDestination;
      }

      if (destination.hasLockedAmount) {
        _amount.value = destination.amountBtc!
            .toStringAsFixed(8)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }

      if (!mounted) return;
      setState(() {
        if (destination.isInternal || destination.hasLockedAmount) {
          _lockedRecipientAddress = destination.normalizedValue;
          if (!destination.isInternal) {
            _recentDestinationAddressForSave = null;
          }
        }
        if (destination.label != null && destination.label!.trim().isNotEmpty) {
          _lockedRecipientLabel = destination.label;
        }
      });

      if (_liveResolvedIntent != null && _liveResolvedIntent!.alternatives.isNotEmpty) {
        final selectedRail = await _showCapabilitiesBottomSheet(_liveResolvedIntent!, destination);
        if (selectedRail == null) {
          // User dismissed the bottom sheet
          return;
        }
        setState(() {
          _userSelectedRail = selectedRail;
        });
      }

      await _pageController.animateToPage(
        1,
        duration: KeroseneMotion.medium,
        curve: KeroseneMotion.standard,
      );
      if (!mounted) return;
      ref.read(sendMoneyFlowProvider.notifier).setStep(1);
    } finally {
      if (mounted && _destinationResolutionBusy) {
        setState(() => _destinationResolutionBusy = false);
      }
    }
  }

  Future<PaymentRail?> _showCapabilitiesBottomSheet(
      ResolvedPaymentIntent resolvedIntent,
      SendDestinationAnalysis destination) async {
    return showModalBottomSheet<PaymentRail>(
      context: context,
      backgroundColor: SendMoneyScreenState.internalBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'receiver_avatar_${destination.normalizedValue}',
                  child: InternalRecentAvatar(
                    title: destination.label ?? destination.normalizedValue,
                    size: 80,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Como deseja enviar?',
                  style: AppTypography.newsreader(
                    color: SendMoneyScreenState.internalText,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha o método de transferência compatível com este recebedor.',
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(
                    color: SendMoneyScreenState.internalMutedText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ...resolvedIntent.alternatives.map((option) {
                  String title = 'Transferência Padrão';
                  String subtitle = 'Pode levar alguns minutos';
                  if (option.rail == PaymentRail.internal ||
                      option.rail == PaymentRail.lightning) {
                    title = 'Transferência Instantânea (Zero taxas)';
                    subtitle = 'Chega na hora';
                  }
                  final isRecommended = option.rail == resolvedIntent.selectedRail;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: SendMoneyScreenState.internalSurfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, option.rail),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: isRecommended
                                ? Border.all(color: KeroseneBrandTokens.textPrimary, width: 2)
                                : Border.all(color: Colors.transparent, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                option.rail == PaymentRail.onchain
                                    ? KeroseneIcons.wallet
                                    : KeroseneIcons.lightning,
                                color: SendMoneyScreenState.internalText,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: AppTypography.inter(
                                        color: SendMoneyScreenState.internalText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: AppTypography.inter(
                                        color: SendMoneyScreenState.internalMutedText,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isRecommended)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: KeroseneBrandTokens.textPrimary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Recomendado',
                                    style: AppTypography.inter(
                                      color: KeroseneBrandTokens.background,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  SendDestinationAnalysis _currentDestinationAnalysis() {
    return currentSendDestinationAnalysis(
      pendingPaymentLinkId: _pendingPaymentLinkId,
      lockedRecipientAddress: _lockedRecipientAddress,
      lockedAmountBtc: _lockedAmountBtc,
      lockedRecipientLabel: _lockedRecipientLabel,
      input: _receiverController.text,
    );
  }

  /// True when destination is the same wallet used as the send source.
  bool _isSameSourceWalletDestination(
    Wallet? sourceWallet,
    SendDestinationAnalysis destination,
  ) {
    if (sourceWallet == null) {
      return false;
    }
    final normalizedDestination =
        destination.normalizedValue.trim().toLowerCase();
    if (normalizedDestination.isEmpty) {
      return false;
    }
    final sourceId = sourceWallet.id.trim().toLowerCase();
    final sourceAddress = sourceWallet.address.trim().toLowerCase();
    return normalizedDestination == sourceId ||
        (sourceAddress.isNotEmpty && normalizedDestination == sourceAddress);
  }

  /// If destination points at the user's own cold wallet (by id), rewrite as
  /// on-chain send to that wallet's receive address.
  SendDestinationAnalysis? _ownColdWalletOnchainDestination(
    WalletState walletState,
    SendDestinationAnalysis destination,
  ) {
    if (!destination.isInternal || walletState is! WalletLoaded) {
      return null;
    }
    final normalized = destination.normalizedValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final wallet in walletState.wallets) {
      if (!wallet.isColdWallet && !wallet.isSelfCustody) {
        continue;
      }
      final walletId = wallet.id.trim().toLowerCase();
      if (walletId != normalized) {
        continue;
      }
      final address = wallet.address.trim();
      if (address.isEmpty || !looksLikeBitcoinAddress(address)) {
        return null;
      }
      return SendDestinationAnalysis(
        type: SendDestinationType.onChain,
        normalizedValue: address,
        amountBtc: destination.amountBtc,
        label: wallet.name.isNotEmpty ? wallet.name : destination.label,
        message: destination.message,
        detectedOnchainNetwork: inferBitcoinNetworkFromAddress(address),
      );
    }
    return null;
  }

  Future<SendDestinationAnalysis?> _resolveDestinationForKfe(
    SendDestinationAnalysis analysis,
  ) async {
    final parser = const PaymentIntentParser();
    final intent = analysis.isInternal
        ? parser.parse(analysis.normalizedValue).copyWith(
              amountBtc: analysis.amountBtc,
              label: analysis.label,
              message: analysis.message,
            )
        : parser.parse(_receiverController.text).copyWith(
              amountBtc: analysis.amountBtc ?? analysis.amountBtc,
              label: analysis.label,
              message: analysis.message,
            );

    // Prefer fresh parse of the free-text field when not locked internal.
    final workingIntent = () {
      if (analysis.isInternal &&
          analysis.normalizedValue.contains('-') &&
          analysis.normalizedValue.length > 30) {
        // Already a wallet UUID lock from a previous resolve.
        return PaymentIntent(
          kind: PaymentDestinationKind.internal,
          rawInput: analysis.normalizedValue,
          normalizedValue: analysis.normalizedValue,
          amountBtc: analysis.amountBtc,
          label: analysis.label,
          message: analysis.message,
        );
      }
      final fromField = parser.parse(_receiverController.text);
      if (fromField.isValid) {
        return fromField.copyWith(
          amountBtc: analysis.amountBtc ?? fromField.amountBtc,
          label: analysis.label ?? fromField.label,
          message: analysis.message ?? fromField.message,
        );
      }
      return intent;
    }();

    final wallet = _selectedWallet ?? _resolveWallet(ref.read(walletProvider));
    final source = sourceCustodyOf(wallet);
    final resolver = PaymentIntentResolver.instance;

    if (!workingIntent.isInternal) {
      // Platform BOLT11 → INTERNAL payment-link settlement (never LND self-pay).
      var intentForResolve = workingIntent;
      if (workingIntent.isLightning) {
        final platformLink = await ref
            .read(transactionRepositoryProvider)
            .lookupPlatformLightningInvoice(workingIntent.normalizedValue);
        if (!mounted) return null;
        if (platformLink != null) {
          intentForResolve = PaymentIntent(
            kind: PaymentDestinationKind.paymentLink,
            rawInput: workingIntent.rawInput,
            normalizedValue: platformLink.id,
            paymentLinkId: platformLink.id,
            amountBtc: platformLink.amountBtc > 0
                ? platformLink.amountBtc
                : workingIntent.amountBtc,
            label: platformLink.description.isNotEmpty
                ? platformLink.description
                : 'Pagamento Kerosene (interno)',
            message: workingIntent.message,
          );
        }
      }
      final local = resolver.resolveLocal(
        intent: intentForResolve,
        source: source,
        sourceWalletId: wallet?.id,
        sourceWalletAddress: wallet?.address,
        userSelectedRail: _userSelectedRail,
        expectedNetwork: expectedBitcoinNetwork,
      );
      if (!local.canContinue) {
        if (mounted && local.blockers.isNotEmpty) {
          SnackbarHelper.showError(local.blockers.first.message);
        }
        return null;
      }
      setState(() => _liveResolvedIntent = local);
      return resolver.toLockedDestination(local);
    }

    try {
      final requestedIdentifier = workingIntent.normalizedValue.trim();
      final capabilities = await ref
          .read(kfeReceivingCapabilitiesServiceProvider)
          .receivingCapabilities(requestedIdentifier);
      if (!mounted) return null;

      final resolved = resolver.resolveWithCapabilities(
        intent: workingIntent,
        source: source,
        capabilities: capabilities,
        userSelectedRail: _userSelectedRail,
        sourceWalletId: wallet?.id,
        sourceWalletAddress: wallet?.address,
        expectedNetwork: expectedBitcoinNetwork,
        destOnchainAddress: capabilities.onchainReceiveAddress,
      );
      setState(() {
        _liveResolvedIntent = resolved;
        _liveResolveError = resolved.blockers.isNotEmpty
            ? resolved.blockers.first.message
            : null;
      });

      if (!resolved.canContinue) {
        SnackbarHelper.showError(
          resolved.blockers.isNotEmpty
              ? resolved.blockers.first.message
              : context.tr.errReceiverNotReady,
        );
        return null;
      }

      if (resolved.selectedRail == PaymentRail.internal) {
        _recentDestinationAddressForSave = requestedIdentifier;
      }
      return resolver.toLockedDestination(resolved);
    } catch (error) {
      if (!mounted) return null;
      SnackbarHelper.showError(
        ErrorTranslator.translate(context.tr, error.toString()),
      );
      return null;
    }
  }

  String _stripLightningPrefix(String value) {
    final trimmed = value.trim();
    return trimmed.toLowerCase().startsWith('lightning:')
        ? trimmed.substring(10).trim()
        : trimmed;
  }

  bool _looksLikeLightningRequest(String value) {
    final trimmed = _stripLightningPrefix(value);
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return RegExp(r'^(lnbc|lntb|lnbcrt)[0-9][0-9a-z]+$').hasMatch(lower) ||
        RegExp(r'^lnurl[0-9a-z]+$').hasMatch(lower) ||
        _looksLikeLightningAddress(trimmed);
  }

  bool _looksLikeLightningAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.length > 254 || trimmed.contains(RegExp(r'\s'))) {
      return false;
    }
    return RegExp(
      r'^[a-zA-Z0-9._%+\-]{1,64}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,63}$',
    ).hasMatch(trimmed);
  }

  bool looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  double? _extractLightningAmountBtc(String value) {
    final withoutPrefix = _stripLightningPrefix(value);
    final match = RegExp(
      r'^ln(?:bc|tb|bcrt)(\d+)([munp]?)1',
    ).firstMatch(withoutPrefix.toLowerCase());
    if (match == null) return null;
    final amount = double.tryParse(match.group(1) ?? '');
    if (amount == null || amount <= 0) return null;

    final multiplier = switch (match.group(2)) {
      'm' => 0.001,
      'u' => 0.000001,
      'n' => 0.000000001,
      'p' => 0.000000000001,
      _ => 1.0,
    };
    return amount * multiplier;
  }

  Widget _buildAmountStep(
    BuildContext context, {
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    required double amountBtc,
    required Wallet? wallet,
    required SendDestinationAnalysis destination,
    required SendFeeQuote feeQuote,
    required bool isLoading,
    required bool isOnline,
  }) {
    // Auto-refresh when quote is stale so the user is not stuck on a dead CTA.
    if (destination.isOnChain &&
        feeQuote.isQuoteExpired &&
        amountBtc > 0 &&
        !_destinationResolutionBusy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(feeEstimateProvider(amountBtc));
      });
    }

    return SendAmountStep(
      onBack: _handleBack,
      amount: _amount,
      selectedCurrency: _selectedCurrency,
      lockedAmountBtc: _lockedAmountBtc,
      hasPaymentLink: _pendingPaymentLinkId != null,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      wallet: wallet,
      destination: destination,
      feeQuote: feeQuote,
      isLoading: isLoading || !isOnline,
      feeTier: _selectedFeeTier,
      onFeeTierChanged: (tier) {
        if (tier == _selectedFeeTier) return;
        HapticFeedback.selectionClick();
        setState(() => _selectedFeeTier = tier);
      },
      onAmountChanged: _onAmountChanged,
      onContinue: _handleContinue,
      resolveAmountBtc: (amountValue) => _currentAmountBtc(
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
        amountVal: amountValue,
      ),
      onFiatReferenceTap: _toggleAmountCurrency,
    );
  }

  String _currentRecipientValue() {
    return _lockedRecipientAddress.isNotEmpty
        ? _lockedRecipientAddress
        : _receiverController.text.trim();
  }

  String _currentRecipientLabel() {
    final label = _lockedRecipientLabel?.trim();
    if (label == null ||
        label.isEmpty ||
        label == context.tr.sendMoneyLockedDestination) {
      return _currentRecipientValue();
    }
    return label;
  }

  Future<void> _openPaymentConfirmation({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required double requestedAmount,
    required SendFeeQuote feeQuote,
    required String toAddress,
  }) async {
    final btcUsd = ref.read(latestBtcPriceProvider);
    final btcEur = ref.read(btcEurPriceProvider);
    final btcBrl = ref.read(btcBrlPriceProvider);
    final isPaymentLink =
        destination.isPaymentLink || _pendingPaymentLinkId != null;

    final result = await openSendPaymentReview(
      context: context,
      wallet: wallet,
      destination: destination,
      requestedAmount: requestedAmount,
      feeQuote: feeQuote,
      toAddress: toAddress,
      recipientLabel: _currentRecipientLabel(),
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      isPaymentLink: isPaymentLink,
      onConfirm: (confirmationContext, {required firstSendAcknowledgedInReview}) =>
          _confirmPayment(
        confirmationContext: confirmationContext,
        wallet: wallet,
        destination: destination,
        amount: amount,
        feeQuote: feeQuote,
        toAddress: toAddress,
        firstSendAcknowledgedInReview: firstSendAcknowledgedInReview,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _showSentTransactionNotification({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final amountLabel = formatBtcValue(amount);
    final destLabel = _currentRecipientLabel();
    final shortDest = destLabel.length > 22
        ? '${destLabel.substring(0, 10)}…${destLabel.substring(destLabel.length - 6)}'
        : destLabel;
    AppNotice.showSuccess(
      context,
      title: SendMoneyCopy.sendSuccessTitle(context),
      message: SendMoneyCopy.sendSuccessBody(
        context,
        amountLabel: '$amountLabel BTC',
        destinationLabel: shortDest,
      ),
    );
  }

  Future<dynamic> _confirmPayment({
    required BuildContext confirmationContext,
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required SendFeeQuote feeQuote,
    required String toAddress,
    bool firstSendAcknowledgedInReview = false,
  }) async {
    return confirmSendPayment(
      context: context,
      confirmationContext: confirmationContext,
      ref: ref,
      wallet: wallet,
      destination: destination,
      amount: amount,
      feeQuote: feeQuote,
      toAddress: toAddress,
      pendingPaymentLinkId: _pendingPaymentLinkId,
      resolveSecurityProfile: _resolveSecurityProfile,
      showSentTransactionNotification: _showSentTransactionNotification,
      resolveRecentDestinationLabel: _resolveRecentInternalDestinationLabel,
      resolveRecentDestinationAddress: _resolveRecentInternalDestinationAddress,
      isMounted: () => mounted,
      firstSendAcknowledgedInReview: firstSendAcknowledgedInReview,
    );
  }

  Future<void> _parsePaymentRequest(String data) async {
    await parseSendPaymentRequest(
      context: context,
      ref: ref,
      data: data,
      isMounted: () => mounted,
      setReceiverText: _setReceiverText,
      setLockedRecipientAddress: (value) => _lockedRecipientAddress = value,
      setLockedAmountBtc: (value) => _lockedAmountBtc = value,
      setAmountText: (value) => _amount.value = value,
      setLockedRecipientLabel: (value) => _lockedRecipientLabel = value,
      incrementDestinationEditVersion: () => _destinationEditVersion += 1,
      fetchPaymentLinkDetails: _fetchPaymentLinkDetails,
    );
  }

  Future<bool> _fetchPaymentLinkDetails(
    String linkId, {
    int? destinationEditVersion,
  }) async {
    return fetchSendPaymentLinkDetails(
      context: context,
      ref: ref,
      linkId: linkId,
      destinationEditVersion: destinationEditVersion,
      currentDestinationEditVersion: () => _destinationEditVersion,
      isMounted: () => mounted,
      incrementDestinationEditVersion: () => _destinationEditVersion += 1,
      setPendingPaymentLinkId: (value) => _pendingPaymentLinkId = value,
      setLockedRecipientLabel: (value) => _lockedRecipientLabel = value,
      setLockedRecipientAddress: (value) => _lockedRecipientAddress = value,
      setLockedAmountBtc: (value) => _lockedAmountBtc = value,
      setAmountText: (value) => _amount.value = value,
    );
  }

  void _setReceiverText(String value) {
    _receiverController.text = value;
    _receiverController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
  }

  void _applyRecentInternalDestination(
    RecentTransactionDestination destination,
  ) {
    final value = destination.address.trim();
    if (value.isEmpty) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _destinationEditVersion += 1;
      _receiverController.text = value;
      _receiverController.selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    });
  }

  String _resolveRecentInternalDestinationAddress(String toAddress) {
    final stableAddress = _recentDestinationAddressForSave?.trim();
    if (stableAddress != null && stableAddress.isNotEmpty) {
      return stableAddress;
    }
    return toAddress;
  }

  String? _resolveRecentInternalDestinationLabel(String toAddress) {
    final label = _lockedRecipientLabel?.trim();
    if (label == null ||
        label.isEmpty ||
        label == toAddress ||
        label == context.tr.sendMoneyLockedDestination) {
      return null;
    }
    return label;
  }

  Future<void> _scanInternalDestination() async {
    // Sheet: QR camera · NFC tag · clipboard paste → same PaymentIntentParser path.
    if (!_ensureOnline()) return;
    final payload = await DestinationCaptureSheet.show(context);
    final value = payload?.trim();
    if (!mounted || value == null || value.isEmpty) {
      return;
    }

    HapticFeedback.selectionClick();
    await _parsePaymentRequest(value);
  }
}

class _OfflineSendBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineSendBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KeroseneBrandTokens.error.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: SendMoneyCopy.offlineBanner(context),
          child: InkWell(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: KeroseneBrandTokens.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      SendMoneyCopy.offlineBanner(context),
                      style: AppTypography.inter(
                        color: KeroseneBrandTokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    context.tr.offlineRetryHint,
                    style: AppTypography.inter(
                      color: KeroseneBrandTokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
