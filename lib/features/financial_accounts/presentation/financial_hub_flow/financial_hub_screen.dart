import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_empty_layout.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart'
    as account_details;
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_header.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/internal_account_creation_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/wallet_setup_hub_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/revolut_account_card.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/design_system/components/generic/app_primary_navigation.dart';
import 'package:kerosene/design_system/components/generic/tor_navigation_loading_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';

import 'sheets/account_details_bottom_sheet.dart';
import 'sheets/wallet_manage_bottom_sheet.dart';
import 'theme/financial_hub_tokens.dart';
import 'widgets/circular_action_bar.dart';

/// Main screen for the Financial Accounts Hub flow.
class FinancialHubScreen extends ConsumerStatefulWidget {
  const FinancialHubScreen({super.key});

  @override
  ConsumerState<FinancialHubScreen> createState() => _FinancialHubScreenState();
}

class _FinancialHubScreenState extends ConsumerState<FinancialHubScreen> {
  int _selectedAccountIndex = 0;
  final Map<String, ReceivingRequestView> _receiveAddressOverrides = {};

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bitcoinAccountsProvider);
    final bottom = AppPrimaryNavigationBar.scaffoldBottomClearance(context);
    final responsive = context.responsive;
    final authState = ref.watch(authControllerProvider);
    final userDisplayName =
        authState is AuthAuthenticated ? authState.user.name.trim() : '';

    return accounts.when(
      loading: () => TorNavigationLoadingScreen(),
      error: (_, __) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Text(
              'Erro ao carregar contas financeiras',
              style: FinancialHubTokens.body(),
            ),
          ),
        ),
      ),
      data: (visibleAccounts) {
        if (visibleAccounts.isEmpty) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: BitcoinAccountsEmptyLayout(
                bottomClearance: bottom,
                onBack: _handleBack,
                onCreateInternalAccount: () {
                  unawaited(_openInternalAccountFlow());
                },
                onCreateColdWallet: () {
                  unawaited(_openColdWalletFlow());
                },
                onRefresh: () =>
                    ref.read(bitcoinAccountsProvider.notifier).refresh(),
              ),
            ),
          );
        }

        final selectedIndex =
            _selectedAccountIndex.clamp(0, visibleAccounts.length - 1);
        final selectedAccount = visibleAccounts[selectedIndex];
        final balanceAmount =
            formatSats(bitcoinAccountVisibleBalance(selectedAccount));

        final requestsAsync = selectedAccount.isWatchOnly
            ? const AsyncValue<List<ReceivingRequestView>>.data([])
            : ref.watch(
                bitcoinAccountReceiveRequestsProvider(selectedAccount.id),
              );

        final txAsync = ref.watch(transactionHistoryProvider);

        final currentReceiveRequest =
            _receiveAddressOverrides[selectedAccount.id] ??
                firstBitcoinReceiveRequest(requestsAsync);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              SafeArea(
                child: RefreshIndicator(
                  color: Theme.of(context).colorScheme.onSurface,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  onRefresh: () =>
                      ref.read(bitcoinAccountsProvider.notifier).refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      responsive.horizontalPadding,
                      16,
                      responsive.horizontalPadding,
                      bottom,
                    ),
                    children: [
                      KeroseneAppColumn(
                        maxWidth: responsive.mobileContentMaxWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BitcoinAccountsHeader(onBack: _handleBack),
                            const SizedBox(height: 16),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    balanceAmount,
                                    style: FinancialHubTokens.balanceAmount(),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Saldo Atual',
                                    style: FinancialHubTokens.titleH2(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            RevolutAccountCardPager(
                              accounts: visibleAccounts,
                              userDisplayName: userDisplayName,
                              selectedIndex: selectedIndex,
                              onChanged: (index) {
                                setState(() {
                                  _selectedAccountIndex = index;
                                });
                              },
                              selectedReceiveRequest: currentReceiveRequest,
                            ),
                            const SizedBox(height: 20),
                            CircularActionBar(
                              onAddWalletTap: () {
                                unawaited(
                                  _openAddWalletFlow(visibleAccounts),
                                );
                              },
                              onManageTap: () {
                                WalletManageBottomSheet.show(
                                  context,
                                  account: selectedAccount,
                                );
                              },
                              onDetailsTap: () {
                                AccountDetailsBottomSheet.show(
                                  context,
                                  account: selectedAccount,
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Transações',
                              style: FinancialHubTokens.titleH1(fontSize: 20),
                            ),
                            const SizedBox(height: 12),
                            account_details.FocusedAccountHistory(
                              account: selectedAccount,
                              transactionsAsync: txAsync,
                              requestsAsync: requestsAsync,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppPrimaryNavigationBar.overlay(
                currentDestination: AppPrimaryDestination.card,
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBack() {
    AppPrimaryNavigationBar.backOrHome(context);
  }

  Future<void> _openAddWalletFlow(List<BitcoinAccount> accounts) async {
    final canInternal = canCreateKeroseneWalletAccount(accounts);
    final canCold = canCreateColdWalletAccount(accounts);

    if (!canInternal && !canCold) {
      if (!mounted) return;
      AppNotice.showInfo(
        context,
        title: context.tr.createWalletTitle,
        message: 'Limite de carteiras ativas atingido.',
      );
      return;
    }

    if (canInternal && canCold) {
      final choice = await _showAddWalletChooser();
      if (!mounted || choice == null) return;
      if (choice == _AddWalletChoice.internal) {
        await _openInternalAccountFlow();
      } else {
        await _openColdWalletFlow();
      }
      return;
    }

    if (canInternal) {
      await _openInternalAccountFlow();
      return;
    }
    await _openColdWalletFlow();
  }

  Future<_AddWalletChoice?> _showAddWalletChooser() {
    return showModalBottomSheet<_AddWalletChoice>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Adicionar outra carteira',
                  style: FinancialHubTokens.titleH2(fontSize: 20),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    KeroseneIcons.wallet,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text(context.tr.bitcoinAccountsNewKeroseneCard),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(_AddWalletChoice.internal);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    KeroseneIcons.security,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: const Text('Cold Wallet'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(_AddWalletChoice.cold);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openInternalAccountFlow() async {
    final changed = await Navigator.of(context).push<bool>(
      keroseneHorizontalRoute<bool>(
        builder: (_) => const InternalAccountCreationFlow(),
      ),
    );
    await _reloadAfterCreate(force: changed == true);
  }

  Future<void> _openColdWalletFlow() async {
    final changed = await Navigator.of(context).push<bool>(
      keroseneHorizontalRoute<bool>(
        builder: (_) => const WalletSetupHubScreen(),
      ),
    );
    await _reloadAfterCreate(force: changed == true);
  }

  Future<void> _reloadAfterCreate({bool force = false}) async {
    if (!mounted) return;
    _receiveAddressOverrides.clear();
    await ref.read(bitcoinAccountsProvider.notifier).refresh();
    if (!mounted) return;
    if (force) {
      setState(() => _selectedAccountIndex = 0);
    }
  }
}

enum _AddWalletChoice { internal, cold }
