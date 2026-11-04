import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/design_system/components/financial/amount_calculator_toolbar.dart';
import 'package:kerosene/design_system/components/financial/amount_entry_surface.dart';
import 'package:kerosene/app/widgets/wallet_expand_chip.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_flow_coordinator.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_to_hub_transition.dart';

/// Step 1 of receive: amount + local wallet, then method hub.
class ReceiveAmountEntryScreen extends ConsumerStatefulWidget {
  const ReceiveAmountEntryScreen({super.key, this.initialWalletId});
  final String? initialWalletId;

  @override
  ConsumerState<ReceiveAmountEntryScreen> createState() =>
      _ReceiveAmountEntryScreenState();
}

class _ReceiveAmountEntryScreenState
    extends ConsumerState<ReceiveAmountEntryScreen> {
  late Currency _selectedCurrency;
  bool _busy = false;
  bool _loadingRequestedWallet = false;
  bool _requestedWalletUnavailable = false;
  Wallet? _selectedWallet;
  AmountCalculatorState _calc = const AmountCalculatorState();

  @override
  void initState() {
    super.initState();
    // Primary unit follows the user's app money preference (BRL / USD / …).
    _selectedCurrency = ref.read(moneyFormatConfigProvider).currency;
    if (widget.initialWalletId == null) {
      final wallets = _eligibleWallets(ref.read(walletProvider));
      if (wallets.isNotEmpty) {
        _selectedWallet = wallets.first;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput('0');
      if (widget.initialWalletId != null) {
        _loadRequestedWallet();
      }
    });
  }

  Future<void> _loadRequestedWallet() async {
    if (_loadingRequestedWallet) return;
    setState(() => _loadingRequestedWallet = true);
    try {
      await ref.read(walletProvider.notifier).refresh();
      if (!mounted) return;
      final selected = _eligibleWallets(ref.read(walletProvider))
          .where((wallet) => wallet.id == widget.initialWalletId)
          .firstOrNull;
      setState(() {
        _selectedWallet = selected;
        _requestedWalletUnavailable = selected == null;
      });
    } catch (_) {
      if (mounted) setState(() => _requestedWalletUnavailable = true);
    } finally {
      if (mounted) setState(() => _loadingRequestedWallet = false);
    }
  }

  double _amountBtc() {
    return MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(_calc.display),
      currency: _selectedCurrency,
      btcUsd: ref.read(latestBtcPriceProvider),
      btcEur: ref.read(btcEurPriceProvider),
      btcBrl: ref.read(btcBrlPriceProvider),
    );
  }

  Future<void> _continue() async {
    if (_busy || _loadingRequestedWallet || _requestedWalletUnavailable) return;
    HapticFeedback.mediumImpact();
    final amountBtc = _amountBtc();
    if (amountBtc <= 0) {
      SnackbarHelper.showError(context.tr.errorAmountRequired);
      return;
    }

    setState(() => _busy = true);
    try {
      final wallets = _eligibleWallets(ref.read(walletProvider));
      if (wallets.isEmpty) {
        SnackbarHelper.showInfo(context.tr.receiveHubNoWalletMessage);
        return;
      }
      final wallet = _selectedWallet ?? wallets.first;
      ref
          .read(movementFlowCoordinatorProvider.notifier)
          .setSelectedWallet(wallet);
      ref
          .read(movementFlowCoordinatorProvider.notifier)
          .setAmountInput(_calc.display);

      await pushReceiveHub(
        context: context,
        wallet: wallet,
        amountBtc: amountBtc,
        money: MovementMoney(
            currency: _selectedCurrency,
            btcDecimalPlaces:
                ref.read(moneyFormatConfigProvider).btcDecimalPlaces,
            locale: Localizations.localeOf(context),
            btcUsd: ref.read(latestBtcPriceProvider),
            btcEur: ref.read(btcEurPriceProvider),
            btcBrl: ref.read(btcBrlPriceProvider)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Wallet> _eligibleWallets(WalletState state) {
    if (state is! WalletLoaded) return const [];
    return state.wallets.where((w) => w.isActive).toList(growable: false);
  }

  void _onAmountChanged(String value) {
    final next = value.trim().isEmpty ? '0' : value;
    final calc = AmountCalculator.onInput(
      state: _calc,
      nextDisplay: next,
      currency: _selectedCurrency,
    );
    setState(() => _calc = calc);
  }

  void _onCalculatorOp(String op) {
    final next = AmountCalculator.onOperator(
      state: _calc,
      operator: op,
      currency: _selectedCurrency,
    );
    setState(() => _calc = next);
    if (next.justResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_calc.justResolved) {
          setState(() => _calc = _calc.copyWith(justResolved: false));
        }
      });
    }
  }

  void _toggleAmountCurrency(Currency fiatCurrency) {
    HapticFeedback.selectionClick();
    final current = MoneyDisplay.parseEditableInput(_calc.display);
    final asBtc = MoneyDisplay.convertToBtcAmount(
      amount: current,
      currency: _selectedCurrency,
      btcUsd: ref.read(latestBtcPriceProvider),
      btcEur: ref.read(btcEurPriceProvider),
      btcBrl: ref.read(btcBrlPriceProvider),
    );
    final nextCurrency =
        _selectedCurrency == Currency.btc ? fiatCurrency : Currency.btc;
    final nextRaw = nextCurrency == Currency.btc
        ? _trimAmountZeros(asBtc.toStringAsFixed(8))
        : _trimAmountZeros(
            MoneyDisplay.convertFromBtcAmount(
              btcAmount: asBtc,
              currency: nextCurrency,
              btcUsd: ref.read(latestBtcPriceProvider),
              btcEur: ref.read(btcEurPriceProvider),
              btcBrl: ref.read(btcBrlPriceProvider),
            ).toStringAsFixed(2),
          );
    setState(() {
      _selectedCurrency = nextCurrency;
      _calc = AmountCalculatorState(display: nextRaw);
    });
  }

  String _trimAmountZeros(String value) {
    if (!value.contains('.')) return value;
    return value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _onWalletSelected(Wallet wallet) {
    setState(() => _selectedWallet = wallet);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(moneyFormatConfigProvider);
    final walletState = ref.watch(walletProvider);
    final wallets = _eligibleWallets(walletState);
    if (widget.initialWalletId != null &&
        (_loadingRequestedWallet ||
            _selectedWallet == null ||
            _requestedWalletUnavailable)) {
      return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _loadingRequestedWallet || !_requestedWalletUnavailable
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(context.tr.walletSelectedUnavailable,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: _loadRequestedWallet,
                              child: Text(context.tr.tryAgain))
                        ]))));
    }

    final effectiveWallet =
        _selectedWallet ?? (wallets.isNotEmpty ? wallets.first : null);

    final amountBtc = MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(_calc.display),
      currency: _selectedCurrency,
      btcUsd: ref.read(latestBtcPriceProvider),
      btcEur: ref.read(btcEurPriceProvider),
      btcBrl: ref.read(btcBrlPriceProvider),
    );
    final fiatCurrency =
        money.currency == Currency.btc ? Currency.brl : money.currency;
    final fiatReference = _selectedCurrency == Currency.btc
        ? ''
        : MovementMoney(locale: money.locale).asset(amountBtc);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: RepaintBoundary(
        child: TransactionValueEntrySurface(
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          showCurrencyPrefix: true,
          showCurrencyChip: false,
          amountInput: _calc.display,
          expressionLabel: _calc.expressionLabel(
            currency: _selectedCurrency,
            locale: Localizations.localeOf(context),
          ),
          resolveAmount: _calc.justResolved,
          unitLabel: MoneyDisplay.tickerSymbolFor(_selectedCurrency),
          currency: _selectedCurrency,
          fiatReference: fiatReference,
          showKeypad: false,
          useSystemKeyboard: true,
          onAmountTextChanged: _onAmountChanged,
          onCurrencyTap: () => _toggleAmountCurrency(fiatCurrency),
          configuration: effectiveWallet == null
              ? null
              : WalletExpandChip(
                  wallets: wallets,
                  selectedWallet: effectiveWallet,
                  onWalletSelected: _onWalletSelected,
                ),
          bottomAccessory: AmountCalculatorToolbar(onOperator: _onCalculatorOp),
          ctaLabel: context.tr.continueButton,
          ctaEnabled: amountBtc > 0 && !_busy && wallets.isNotEmpty,
          isBusy: _busy,
          onCta: _continue,
        ),
      ),
    );
  }
}
