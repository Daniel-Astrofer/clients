import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/design_system/components/financial/amount_calculator_toolbar.dart';
import 'package:kerosene/design_system/components/financial/amount_entry_surface.dart';
import 'package:kerosene/design_system/components/financial/wallet_expand_chip.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_flow_coordinator.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_to_hub_transition.dart';

/// Step 1 of receive: amount + local wallet, then method hub.
class ReceiveAmountEntryScreen extends ConsumerStatefulWidget {
  const ReceiveAmountEntryScreen({super.key});

  @override
  ConsumerState<ReceiveAmountEntryScreen> createState() =>
      _ReceiveAmountEntryScreenState();
}

class _ReceiveAmountEntryScreenState
    extends ConsumerState<ReceiveAmountEntryScreen> {
  late Currency _selectedCurrency;
  bool _busy = false;
  Wallet? _selectedWallet;
  AmountCalculatorState _calc = const AmountCalculatorState();

  @override
  void initState() {
    super.initState();
    // Primary unit follows the user's app money preference (BRL / USD / …).
    _selectedCurrency = ref.read(moneyFormatConfigProvider).currency;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput('0');
      _ensureDefaultWallet();
    });
  }

  void _ensureDefaultWallet() {
    final wallets = _eligibleWallets(ref.read(walletProvider));
    if (wallets.isEmpty) return;
    final stillValid = _selectedWallet != null &&
        wallets.any((w) => w.id == _selectedWallet!.id);
    if (!stillValid) {
      setState(() => _selectedWallet = wallets.first);
    }
  }

  double _amountBtc() {
    final flow = ref.read(movementFlowCoordinatorProvider);
    return MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(flow.amountInput),
      currency: _selectedCurrency,
      btcUsd: ref.read(latestBtcPriceProvider),
      btcEur: ref.read(btcEurPriceProvider),
      btcBrl: ref.read(btcBrlPriceProvider),
    );
  }

  Future<void> _continue() async {
    if (_busy) return;
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

      await pushReceiveHub(
        context: context,
        wallet: wallet,
        amountBtc: amountBtc,
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
    ref
        .read(movementFlowCoordinatorProvider.notifier)
        .setAmountInput(calc.display);
  }

  void _onCalculatorOp(String op) {
    final next = AmountCalculator.onOperator(
      state: _calc.copyWith(
        display: ref.read(movementFlowCoordinatorProvider).amountInput,
      ),
      operator: op,
      currency: _selectedCurrency,
    );
    setState(() => _calc = next);
    ref
        .read(movementFlowCoordinatorProvider.notifier)
        .setAmountInput(next.display);
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
    final flow = ref.read(movementFlowCoordinatorProvider);
    final current = MoneyDisplay.parseEditableInput(flow.amountInput);
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
    ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput(nextRaw);
  }

  String _trimAmountZeros(String value) {
    if (!value.contains('.')) return value;
    return value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _onWalletSelected(Wallet wallet) {
    setState(() => _selectedWallet = wallet);
    ref
        .read(movementFlowCoordinatorProvider.notifier)
        .setSelectedWallet(wallet);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(movementFlowCoordinatorProvider);
    final money = ref.watch(moneyFormatConfigProvider);
    final walletState = ref.watch(walletProvider);
    final wallets = _eligibleWallets(walletState);

    // Keep selection valid as wallets load/refresh.
    if (wallets.isNotEmpty) {
      final valid = _selectedWallet != null &&
          wallets.any((w) => w.id == _selectedWallet!.id);
      if (!valid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ensureDefaultWallet();
        });
      }
    }

    final amountBtc = MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(flow.amountInput),
      currency: _selectedCurrency,
      btcUsd: ref.watch(latestBtcPriceProvider),
      btcEur: ref.watch(btcEurPriceProvider),
      btcBrl: ref.watch(btcBrlPriceProvider),
    );
    final fiatCurrency =
        money.currency == Currency.btc ? Currency.brl : money.currency;
    final fiatReference = _selectedCurrency == Currency.btc
        ? '≈ ${MoneyDisplay.formatAmountFromBtc(
            btcAmount: amountBtc,
            currency: fiatCurrency,
            btcUsd: ref.watch(latestBtcPriceProvider),
            btcEur: ref.watch(btcEurPriceProvider),
            btcBrl: ref.watch(btcBrlPriceProvider),
          )}'
        : '≈ ${MoneyDisplay.formatCompact(
            amount: amountBtc,
            currency: Currency.btc,
            maxDecimalPlaces: 8,
          )}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: TransactionValueEntrySurface(
        onBack: () => Navigator.of(context).maybePop(),
        showCurrencyPrefix: true,
        showCurrencyChip: false,
        amountInput: flow.amountInput,
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
        configuration: wallets.isEmpty
            ? null
            : WalletExpandChip(
                wallets: wallets,
                selectedWallet: _selectedWallet ?? wallets.first,
                onWalletSelected: _onWalletSelected,
              ),
        bottomAccessory: AmountCalculatorToolbar(onOperator: _onCalculatorOp),
        ctaLabel: context.tr.continueButton,
        ctaEnabled: amountBtc > 0 && !_busy && wallets.isNotEmpty,
        isBusy: _busy,
        onCta: _continue,
      ),
    );
  }
}
