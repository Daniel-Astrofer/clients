// ignore_for_file: unused_import, unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/presentation/widgets/app_notification_surface.dart';
import 'package:kerosene/core/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/core/presentation/widgets/kerosene_logo.dart';
import 'package:kerosene/core/providers/currency_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/shared/widgets/state_feedback_view.dart';
import 'package:kerosene/shared/widgets/bitcoin_refresh_indicator.dart';
import 'package:kerosene/shared/widgets/bouncing_button_wrapper.dart';

import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/screens/movement_hub_screen.dart'
    deferred as deposits;
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/widgets/statement_transaction_card.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/widgets/receive_flow_ui.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/wallet_flow_selector.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import 'package:kerosene/features/movement/screens/send_money_screen.dart'
    deferred as send_money;
import '../widgets/animated_balance_display.dart';
import '../widgets/home_bitcoin_market_chart_card.dart';
import '../widgets/home_onboarding_progress_card.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:kerosene/features/notifications/presentation/notification_visuals.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';

import 'package:kerosene/features/home/presentation/providers/home_feed_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_greeting_slot.dart';
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';
import 'package:kerosene/features/home/presentation/widgets/home_education_host.dart';

import '../design/home_design_tokens.dart';
export '../design/home_design_tokens.dart';

import 'home_screen_surface.dart';
import 'home_screen_education.dart';
import 'home_screen_send_method.dart';
import 'home_screen_payment_link.dart';
import 'home_screen_balance.dart';
import 'home_screen_navigation.dart';
import 'home_screen_transactions.dart';

/// Home balance carousel pages — only pages the user actually has appear.
enum HomeLedgerBalanceView {
  /// Sum of every active balance.
  total,

  /// Custodial on-chain (hot chain custody).
  onChain,

  /// Watch-only / cold vault.
  cold,

  /// Internal Kerosene ledger (global / card).
  platform,
}

enum HomeActivityFilter {
  all,
  incoming,
  outgoing,
  /// Internal ledger (instant).
  internal,
  onchain,
  /// Lightning rail (was missing from home chips).
  lightning,
  cold,
  /// pending + confirming + reconciling.
  pending,
  /// failed + unconfirmed expired.
  failed,
  cancelled,
}

final homeLedgerBalanceViewProvider = StateProvider<HomeLedgerBalanceView>((
  ref,
) {
  return HomeLedgerBalanceView.total;
});

final homeLedgerBalancePageProvider = StateProvider<int>((ref) => 0);

final homeActivityFilterProvider = StateProvider<HomeActivityFilter>((ref) {
  return HomeActivityFilter.all;
});

final homeRouteActiveProvider = StateProvider<bool>((ref) => true);



bool isLightningPaymentPayload(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final withoutPrefix = trimmed.toLowerCase().startsWith('lightning:')
      ? trimmed.substring(10).trim()
      : trimmed;
  final lower = withoutPrefix.toLowerCase();

  return RegExp(r'^(lnbc|lntb|lnbcrt)[0-9][0-9a-z]+$').hasMatch(lower) ||
      RegExp(r'^lnurl[0-9a-z]+$').hasMatch(lower);
}

bool isOnChainPaymentPayload(String raw, String candidate) {
  final trimmedRaw = raw.trim().toLowerCase();
  final trimmedCandidate = candidate.trim();

  return trimmedRaw.startsWith('bitcoin:') ||
      RegExp(
        r'^(1|3|bc1|m|n|2|tb1|bcrt1)[a-zA-HJ-NP-Z0-9]{20,90}$',
      ).hasMatch(trimmedCandidate);
}

double? extractLightningAmountBtc(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final withoutPrefix = trimmed.toLowerCase().startsWith('lightning:')
      ? trimmed.substring(10).trim()
      : trimmed;
  final match = RegExp(
    r'^ln(?:bc|tb|bcrt)(\d+)([munp]?)1',
  ).firstMatch(withoutPrefix.toLowerCase());
  if (match == null) {
    return null;
  }

  final amount = double.tryParse(match.group(1) ?? '');
  if (amount == null || amount <= 0) {
    return null;
  }

  final multiplier = switch (match.group(2)) {
    'm' => 0.001,
    'u' => 0.000001,
    'n' => 0.000000001,
    'p' => 0.000000000001,
    _ => 1.0,
  };
  return amount * multiplier;
}

Route<T> _buildBottomUpRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return keroseneHorizontalRoute<T>(settings: settings, builder: builder);
}

class HomeScreen extends ConsumerStatefulWidget {
  static bool skipNextAuth = false;
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Future<void>? _refreshHomeFuture;
  String? _firstUseActionPanelUserId;
  late final StateController<bool> homeRouteActiveController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeRouteActiveController = ref.read(homeRouteActiveProvider.notifier);
    Future.microtask(() => homeRouteActiveController.state = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshHomeData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Future.microtask(() => homeRouteActiveController.state = false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Background/WS may have marked dirty — pull extrato + balance together.
      unawaited(refreshFinancialProjectionIfDirty(ref));
    }
  }

  Wallet? _resolveActiveWallet(WalletState walletState) {
    if (walletState is! WalletLoaded) {
      return null;
    }

    return walletState.selectedWallet ??
        (walletState.wallets.isNotEmpty ? walletState.wallets.first : null);
  }

  void _showWalletRequiredNotice() {
    AppNotice.showInfo(
      context,
      title: context.tr.homeWalletRequiredTitle,
      message: context.tr.homeWalletRequiredMessage,
    );
  }

  Future<void> _refreshHomeData() async {
    final activeRefresh = _refreshHomeFuture;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _performHomeRefresh();
    _refreshHomeFuture = refresh;

    return refresh.whenComplete(() {
      if (identical(_refreshHomeFuture, refresh)) {
        _refreshHomeFuture = null;
      }
    });
  }

  Future<void> _performHomeRefresh() async {
    try {
      ref.invalidate(homeFeedProvider);
      await Future.wait<dynamic>([
        refreshFinancialProjectionUi(ref, forceFullHistory: true),
        ref.read(homeSurfaceProvider.notifier).refresh(),
      ], eagerError: false);
    } catch (_) {}
  }

  Future<T?> _pushFromBottom<T>(WidgetBuilder builder) {
    return Navigator.of(context).push<T>(_buildBottomUpRoute(builder: builder));
  }

  Future<void> _syncAfterFinancialAction() async {
    await refreshFinancialProjectionUi(ref, forceFullHistory: true);
  }

  Future<void> _presentFinancialActionResult(dynamic result) async {
    if (result == null) {
      return;
    }

    await _syncAfterFinancialAction();

    if (!mounted) {
      return;
    }

    if (result is TxStatus) {
      return;
    }

    if (result is PaymentLink) {
      return;
    }
  }

  Future<void> _openSendFlow({
    required Wallet wallet,
    String? initialAddress,
    double? initialAmountBtc,
  }) async {
    final result = await _pushWalletSelectorFlow<dynamic>(
      title: context.tr.send,
      subtitle: context.tr.walletSelectorSendSubtitle,
      initialWallet: wallet,
      destinationBuilder: (selectedWallet) => DeferredPage(
        loadLibrary: send_money.loadLibrary,
        builder: (_) => send_money.SendMoneyScreen(
          walletId: selectedWallet.id,
          initialAddress: initialAddress,
          initialAmountBtc: initialAmountBtc,
        ),
      ),
    );

    await _presentFinancialActionResult(result);
  }

  Future<T?> _pushWalletSelectorFlow<T>({
    required String title,
    required String subtitle,
    required Wallet initialWallet,
    required Widget Function(Wallet wallet) destinationBuilder,
  }) {
    return _pushFromBottom<T>(
      (selectorContext) => WalletFlowSelector(
        title: title,
        subtitle: subtitle,
        initialWallet: initialWallet,
        onContinue: (selectedWallet) {
          Navigator.of(selectorContext).pushReplacement<T, void>(
            _buildBottomUpRoute<T>(
              builder: (_) => destinationBuilder(selectedWallet),
            ),
          );
        },
      ),
    );
  }

  void _openSend(Wallet? wallet) {
    HapticFeedback.lightImpact();

    if (wallet == null) {
      _showWalletRequiredNotice();
      return;
    }

    unawaited(_openSendFlow(wallet: wallet));
  }

  void _openReceiveFlow(Wallet? wallet) {
    HapticFeedback.lightImpact();

    if (wallet == null) {
      _showWalletRequiredNotice();
      return;
    }

    unawaited(
      _pushWalletSelectorFlow<void>(
        title: context.tr.receive,
        subtitle: context.tr.walletSelectorReceiveSubtitle,
        initialWallet: wallet,
        destinationBuilder: (selectedWallet) => DeferredPage(
          loadLibrary: deposits.loadLibrary,
          builder: (_) =>
              deposits.MovementHubScreen(initialWallet: selectedWallet),
        ),
      ),
    );
  }

  void _openDeposit(Wallet? wallet) {
    if (wallet == null) {
      HapticFeedback.lightImpact();
      _showWalletRequiredNotice();
      return;
    }

    _openDepositForWallet(wallet);
  }

  void _openDepositForWallet(Wallet wallet) {
    HapticFeedback.lightImpact();

    unawaited(
      _pushWalletSelectorFlow<void>(
        title: context.tr.depositFlowDepositTitle,
        subtitle: context.tr.walletSelectorDepositSubtitle,
        initialWallet: wallet,
        destinationBuilder: (selectedWallet) => DeferredPage(
          loadLibrary: deposits.loadLibrary,
          builder: (_) =>
              deposits.MovementHubScreen(initialWallet: selectedWallet),
        ),
      ),
    );
  }

  void _openCreateWallet() {
    HapticFeedback.lightImpact();
    unawaited(_openCreateWalletFlow());
  }

  Future<void> _openCreateWalletFlow() async {
    await _pushFromBottom<void>(
      (_) => DeferredPage(
        loadLibrary: bitcoin_accounts.loadLibrary,
        builder: (_) => bitcoin_accounts.BitcoinAccountsScreen(),
      ),
    );
    if (!mounted) {
      return;
    }

    unawaited(refreshFinancialProjectionUi(ref));
  }

  String _firstUseActionPanelKey(String userId) =>
      'home.first_use_action_panel_seen.$userId';

  bool _hasSeenFirstUseActionPanel(String? userId) {
    if (userId == null || userId.isEmpty) {
      return true;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_firstUseActionPanelKey(userId)) ?? false;
  }

  void _activateFirstUseActionPanel(String userId) {
    if (_firstUseActionPanelUserId == userId) {
      return;
    }

    _firstUseActionPanelUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setBool(_firstUseActionPanelKey(userId), true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    // Fill the window — never pin to phone width on Linux/desktop.
    final contentMaxWidth = responsive.appColumnMaxWidth;
    final pageHorizontalPadding = responsive.isTinyPhone
        ? homeSize(18)
        : responsive.isCompact
            ? homeSize(24)
            : responsive.isWide
                ? AppSpacing.xxxl
                : responsive.horizontalPadding;
    final useWideHomeLayout = responsive.useWideHomeLayout;
    final navigationClearance =
        MediaQuery.viewPaddingOf(context).bottom + homeSize(32);

    final authenticatedUserId = ref.watch(
        authControllerProvider.select((s) => s is AuthAuthenticated ? s.user.id : null));
    final authenticatedUserName = ref.watch(
        authControllerProvider.select((s) => s is AuthAuthenticated ? s.user.name.trim() : ''));
    final authIsLoading = ref.watch(
        authControllerProvider.select((s) => s is AuthLoading));

    final activeWallet = ref.watch(
        walletProvider.select((w) => _resolveActiveWallet(w)));
    final isWalletLoading = ref.watch(
        walletProvider.select((w) => w is WalletInitial || w is WalletLoading));

    final transactionHistoryAsync = ref.watch(transactionHistoryProvider);
    final hasWallet = activeWallet != null;
    final hasBalance = (activeWallet?.balance ?? 0) > 0;
    final isReadyActionsVariant = hasWallet && hasBalance;
    final transactionHistory =
        transactionHistoryAsync.asData?.value ?? const <Transaction>[];
    final hasLoadedTransactionHistory = transactionHistoryAsync.hasValue;
    final hasTransactions = transactionHistory.isNotEmpty;
    final hasSeenFirstUseActionPanel = _hasSeenFirstUseActionPanel(
      authenticatedUserId,
    );

    if (authenticatedUserId == null) {
      _firstUseActionPanelUserId = null;
    }

    // Do not open first-use "deposit" when balance already exists but history
    // is still empty (race / sync lag) — that confuses users who just received.
    if (authenticatedUserId != null &&
        isReadyActionsVariant &&
        hasLoadedTransactionHistory &&
        !hasTransactions &&
        !hasBalance &&
        !hasSeenFirstUseActionPanel) {
      _activateFirstUseActionPanel(authenticatedUserId);
    }

    final showFirstUseReadyPanel = authenticatedUserId != null &&
        isReadyActionsVariant &&
        !hasTransactions &&
        _firstUseActionPanelUserId == authenticatedUserId;
    final showPrimaryActionPanel =
        !isReadyActionsVariant || showFirstUseReadyPanel;
    // Full-body dots only while wallets have never loaded.
    // History loading must not replace the home with a second (higher) dots
    // strip after the post-PIN TorNavigationLoadingScreen already finished.
    final showHomeLoading = isWalletLoading;

    void openStatement() {
      unawaited(
        _pushFromBottom<void>(
          (_) => DeferredPage(
            loadLibrary: deposits.loadLibrary,
            builder: (_) => deposits.TransactionStatementScreen(),
          ),
        ),
      );
    }

    // ── NOME DE USUÁRIO REAL E SEGURO ──
    String userName = '';

    if (authenticatedUserName.isNotEmpty) {
      userName =
          authenticatedUserName.split(' ').first; // Pega o primeiro nome para UI limpa
    } else if (activeWallet != null) {
      userName = activeWallet.name;
    } else if (authIsLoading) {
      userName = '...';
    }

    if (userName.isEmpty || userName == 'Not Found') {
      userName = context.tr.homeFallbackUser;
    }

    final layout = ref.watch(homeSurfaceProvider.select((s) => s.layout));
    final gapAfterHeader = homeSize(layout.sectionGapAfterHeader);
    final gapBeforeFeed = homeSize(layout.sectionGapBeforeFeed);
    // Scaffold paints this solid so pull-to-refresh overscroll matches the
    // header (Flutter stretch-header pattern). Header itself scrolls away.
    final scaffoldSolid = ref.watch(theaterScaffoldSolidColorProvider);
    final pageTopPad =
        responsive.isTinyPhone ? homeSize(8) : homeSize(16);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: homeBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        // Same solid as header top → overscroll is continuous (no black cut).
        backgroundColor: scaffoldSolid,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const HomeRealtimeBootstrap(),
            // Theater education / receive messages (Communication Stage).
            const HomeEducationHost(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                BitcoinRefreshIndicator(onRefresh: _refreshHomeData),
                // ── HEADER (scrolls away): wash only on theater row; balance on black
                // KeroseneAppColumn forces full window width (not phone shrink-wrap).
                SliverToBoxAdapter(
                  child: KeroseneAppColumn(
                    maxWidth: contentMaxWidth,
                    child: showHomeLoading
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              pageHorizontalPadding,
                              pageTopPad +
                                  MediaQuery.paddingOf(context).top,
                              pageHorizontalPadding,
                              homeSize(8),
                            ),
                            child: const HomeLoadingContent()
                                .animate()
                                .fade(duration: 220.ms),
                          )
                        : HomeEntryTransition(
                            child: HomeBalanceSection(
                              userName: userName,
                              walletState: ref.read(walletProvider),
                              activeWallet: activeWallet,
                              pageHorizontalPadding: pageHorizontalPadding,
                              pageTopPad: pageTopPad,
                              onReceive: () =>
                                  _openReceiveFlow(activeWallet),
                              onSend: () => _openSend(activeWallet),
                              onViewStatement: openStatement,
                              onOpenWallets: () =>
                                  AppPrimaryNavigationBar.navigateTo(
                                context,
                                AppPrimaryDestination.card,
                              ),
                            ),
                          ),
                  ),
                ),
                // ── FEED: solid black covers scaffold so body stays black
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: homeBackgroundColor,
                    child: KeroseneAppColumn(
                      maxWidth: contentMaxWidth,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          pageHorizontalPadding,
                          gapAfterHeader,
                          pageHorizontalPadding,
                          navigationClearance,
                        ),
                        child: showHomeLoading
                            ? const SizedBox.shrink()
                            : _HomeFeedBody(
                                useWideLayout: useWideHomeLayout,
                                gapAfterHeader: gapAfterHeader,
                                gapBeforeFeed: gapBeforeFeed,
                                showPrimaryActionPanel: showPrimaryActionPanel,
                                hasWallet: hasWallet,
                                hasBalance: hasBalance,
                                hasTransactions: hasTransactions,
                                onOpenCreateWallet: _openCreateWallet,
                                onOpenDeposit: () =>
                                    _openDeposit(activeWallet),
                                onOpenSend: () => _openSend(activeWallet),
                                onOpenStatement: openStatement,
                                onDepositWallet: _openDepositForWallet,
                                walletState: ref.read(walletProvider),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const HomeBottomNavigationOverlay(
              currentDestination: AppPrimaryDestination.home,
            ),
          ],
        ),
      ),
    );
  }
}

/// Home feed body — single column on phones/tablets, two columns on desktop.
class _HomeFeedBody extends StatelessWidget {
  final bool useWideLayout;
  final double gapAfterHeader;
  final double gapBeforeFeed;
  final bool showPrimaryActionPanel;
  final bool hasWallet;
  final bool hasBalance;
  final bool hasTransactions;
  final VoidCallback onOpenCreateWallet;
  final VoidCallback onOpenDeposit;
  final VoidCallback onOpenSend;
  final VoidCallback onOpenStatement;
  final ValueChanged<Wallet> onDepositWallet;
  final WalletState walletState;

  const _HomeFeedBody({
    required this.useWideLayout,
    required this.gapAfterHeader,
    required this.gapBeforeFeed,
    required this.showPrimaryActionPanel,
    required this.hasWallet,
    required this.hasBalance,
    required this.hasTransactions,
    required this.onOpenCreateWallet,
    required this.onOpenDeposit,
    required this.onOpenSend,
    required this.onOpenStatement,
    required this.onDepositWallet,
    required this.walletState,
  });

  @override
  Widget build(BuildContext context) {
    final setupNotice = showPrimaryActionPanel
        ? HomeSetupNotice(
            icon: !hasWallet
                ? KeroseneIcons.wallet
                : !hasBalance
                    ? KeroseneIcons.download
                    : KeroseneIcons.send,
            title: !hasWallet
                ? context.l10n.homePrimaryNoWalletTitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceTitle
                    : context.tr.homePrimaryReadyTitle,
            subtitle: !hasWallet
                ? context.tr.homePrimaryNoWalletSubtitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceSubtitle
                    : context.tr.homePrimaryReadySubtitle,
            actionLabel: !hasWallet
                ? context.l10n.homeCreateWalletAction
                : !hasBalance
                    ? context.tr.homeDepositFundsAction
                    : context.l10n.homeSendBtcAction,
            onAction: !hasWallet
                ? onOpenCreateWallet
                : !hasBalance
                    ? onOpenDeposit
                    : onOpenSend,
          )
        : null;

    final insightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeOnboardingProgressCard(),
        SizedBox(height: gapAfterHeader),
        const HomeBitcoinMarketChartCard(),
        if (setupNotice != null) ...[
          SizedBox(height: gapAfterHeader),
          setupNotice,
        ],
        SizedBox(height: gapBeforeFeed),
        const HomeEducationCarousel(),
        SizedBox(height: homeSize(AppSpacing.md)),
        SizedBox(height: homeSize(AppSpacing.xl)),
        HomeFundsDistributionSection(
          walletState: walletState,
          onViewStatement: onOpenStatement,
        ),
      ],
    );

    final activityColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: homeRecentActivitiesTitle(context),
          onAction: onOpenStatement,
        ),
        SizedBox(height: homeSize(AppSpacing.md)),
        if (hasTransactions) ...[
          const HomeActivityFilterChips(),
          SizedBox(height: homeSize(AppSpacing.md)),
        ],
        HomeTransactionsList(
          onCreateWallet: onOpenCreateWallet,
          onDepositWallet: onDepositWallet,
        ),
      ],
    );

    if (!useWideLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          insightColumn,
          SizedBox(height: homeSize(AppSpacing.xl)),
          activityColumn,
        ],
      );
    }

    // Desktop / large Linux windows: market + education left, activity right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: insightColumn),
        SizedBox(width: homeSize(AppSpacing.xl)),
        Expanded(flex: 4, child: activityColumn),
      ],
    );
  }
}
