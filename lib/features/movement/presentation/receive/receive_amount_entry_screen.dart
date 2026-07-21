import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/design_system/components/financial/amount_entry_surface.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_flow_coordinator.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_to_hub_transition.dart';

/// Step 1 of receive: amount only. Wallet is chosen next via bottom sheet.
class ReceiveAmountEntryScreen extends ConsumerStatefulWidget {
  const ReceiveAmountEntryScreen({super.key});

  @override
  ConsumerState<ReceiveAmountEntryScreen> createState() =>
      _ReceiveAmountEntryScreenState();
}

class _ReceiveAmountEntryScreenState
    extends ConsumerState<ReceiveAmountEntryScreen> {
  Currency _selectedCurrency = Currency.btc;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput('0');
    });
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
      final walletState = ref.read(walletProvider);
      final wallets = _eligibleWallets(walletState);
      if (wallets.isEmpty) {
        SnackbarHelper.showInfo(context.tr.receiveHubNoWalletMessage);
        return;
      }

      await pushReceiveWalletToHub(
        context: context,
        wallets: wallets,
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
    ref.read(movementFlowCoordinatorProvider.notifier).setAmountInput(
          value.trim().isEmpty ? '0' : value,
        );
  }

  void _toggleAmountCurrency(Currency fiatCurrency) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCurrency = _selectedCurrency == Currency.btc
          ? fiatCurrency
          : Currency.btc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(movementFlowCoordinatorProvider);
    final money = ref.watch(moneyFormatConfigProvider);
    final amountBtc = MoneyDisplay.convertToBtcAmount(
      amount: MoneyDisplay.parseEditableInput(flow.amountInput),
      currency: _selectedCurrency,
      btcUsd: ref.watch(latestBtcPriceProvider),
      btcEur: ref.watch(btcEurPriceProvider),
      btcBrl: ref.watch(btcBrlPriceProvider),
    );
    final fiatCurrency =
        money.currency == Currency.btc ? Currency.usd : money.currency;
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
      backgroundColor: KeroseneBrandTokens.background,
      resizeToAvoidBottomInset: false,
      body: TransactionValueEntrySurface(
        onBack: () => Navigator.of(context).maybePop(),
        title: ReceiveMoneyCopy.receiveAmountTitle(context),
        titleStyle: AppTypography.h1.copyWith(
          color: KeroseneBrandTokens.textPrimary,
        ),
        titleViewportFraction: ReceiveFlowLayout.titleViewportFraction,
        inlineHeroTitle: true,
        amountInput: flow.amountInput,
        unitLabel: MoneyDisplay.tickerSymbolFor(_selectedCurrency),
        currency: _selectedCurrency,
        fiatReference: fiatReference,
        showKeypad: false,
        useSystemKeyboard: true,
        onAmountTextChanged: _onAmountChanged,
        onCurrencyTap: () => _toggleAmountCurrency(fiatCurrency),
        ctaLabel: context.tr.continueButton,
        ctaEnabled: amountBtc > 0 && !_busy,
        isBusy: _busy,
        onCta: _continue,
      ),
    );
  }
}
