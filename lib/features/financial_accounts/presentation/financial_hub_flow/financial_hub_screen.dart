import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_empty_layout.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_header.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/revolut_account_card.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/features/presentation/widgets/tor_navigation_loading_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';

import 'sheets/account_details_bottom_sheet.dart';
import 'sheets/receive_bottom_sheet.dart';
import 'sheets/send_bottom_sheet.dart';
import 'sheets/wallet_manage_bottom_sheet.dart';
import 'theme/financial_hub_tokens.dart';
import 'widgets/circular_action_bar.dart';

/// Main screen for the Financial Accounts Hub flow.
/// Implements the image structure (Balance -> Card -> Circular Action Buttons -> Recent Transactions)
/// with modal bottom sheets for each circular button, styled with Playfair Display (Titles) and Plus Jakarta Sans (Body/Numbers).
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
      loading: () => const TorNavigationLoadingScreen(),
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
                onCreateInternalAccount: () {},
                onCreateColdWallet: () {},
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

                            // Balance Header Display
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    balanceAmount,
                                    style: FinancialHubTokens.balanceAmount(),
                                  ),
                                  const SizedBox(height: 4),
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

                            // Center Card View / Carousel
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

                            // Circular Action Buttons Row
                            CircularActionBar(
                              onReceiveTap: () {
                                ReceiveBottomSheet.show(
                                  context,
                                  account: selectedAccount,
                                  request: currentReceiveRequest,
                                  onAddressRotated: (request) {
                                    setState(() {
                                      _receiveAddressOverrides[
                                          selectedAccount.id] = request;
                                    });
                                  },
                                );
                              },
                              onSendTap: () {
                                SendBottomSheet.show(
                                  context,
                                  account: selectedAccount,
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

                            // Recent Transactions Section
                            Text(
                              'Transações',
                              style: FinancialHubTokens.titleH1(fontSize: 20),
                            ),
                            const SizedBox(height: 12),

                            FocusedAccountHistory(
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
}
