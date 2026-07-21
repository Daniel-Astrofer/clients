// ignore_for_file: unused_import, unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/components/feedback/app_notification_surface.dart';
import 'package:kerosene/features/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/features/presentation/widgets/kerosene_logo.dart';
import 'package:kerosene/core/providers/currency_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/design_system/components/feedback/state_feedback_view.dart';
import 'package:kerosene/shared/widgets/bitcoin_refresh_indicator.dart';
import 'package:kerosene/shared/widgets/bouncing_button_wrapper.dart';

import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/presentation/hub/movement_hub_screen.dart'
    deferred as deposits;
import 'package:kerosene/features/movement/presentation/send/send_money_screen.dart'
    deferred as send_money;
import 'package:kerosene/features/movement/presentation/receive/receive_amount_entry_screen.dart'
    deferred as receive;
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_ui.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/wallet_flow_selector.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import '../widgets/animated_balance_display.dart';
import '../widgets/home_bitcoin_market_chart_card.dart';
import '../widgets/home_onboarding_progress_card.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:kerosene/features/notifications/presentation/notification_visuals.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';

import 'package:kerosene/features/home/presentation/layers/home_layers.dart';
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

  /// Local archive after user opens a cancelled item.
  archived,
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
    with WidgetsBindingObserver, FinancialSurfaceMixin {
  Future<void>? _refreshHomeFuture;
  String? _firstUseActionPanelUserId;
  late final StateController<bool> homeRouteActiveController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeRouteActiveController = ref.read(homeRouteActiveProvider.notifier);
    // Post-frame (not raw microtask): avoids writing provider state while the
    // element is still mounting, and skips work if we unmounted already
    // (e.g. off-screen gallery capture).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        homeRouteActiveController.state = true;
      } catch (_) {}
      _refreshHomeData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // NEVER write providers synchronously in dispose during tree teardown
    // (hot restart / route pop) — Riverpod notifies listeners that are already
    // defunct → `_lifecycleState != defunct` crashes.
    final routeActive = homeRouteActiveController;
    super.dispose();
    Future<void>(() {
      try {
        routeActive.state = false;
      } catch (_) {}
    });
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
    String? initialAddress,
    double? initialAmountBtc,
  }) async {
    // Ensure the deferred send unit is loaded before the slide starts — otherwise
    // the first Enviar animates a placeholder and swaps mid-transition (jank).
    try {
      await loadDeferredLibrary(
        send_money.loadLibrary,
        key: DeferredLibraryKeys.sendMoney,
      );
    } catch (_) {
      // DeferredPage on the route will surface the error if load still fails.
    }
    if (!mounted) return;

    final params = <String, String>{};
    if (initialAddress != null && initialAddress.trim().isNotEmpty) {
      params['address'] = initialAddress.trim();
    }
    if (initialAmountBtc != null) {
      params['amount'] = initialAmountBtc.toString();
    }
    final location = Uri(
      path: '/send-money',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
    if (!mounted) return;
    context.go(location);
  }

  Future<T?> _pushDirectFlow<T>({
    required Widget Function() builder,
  }) {
    return _pushFromBottom<T>((context) => builder());
  }

  void _openSend() {
    HapticFeedback.lightImpact();
    unawaited(_openSendFlow());
  }

  void _openReceiveFlow() {
    HapticFeedback.lightImpact();
    unawaited(_openReceiveFlowAsync());
  }

  Future<void> _openReceiveFlowAsync() async {
    // Ensure the deferred receive unit is loaded before the slide starts —
    // otherwise the first Receber animates a placeholder and swaps mid-transition.
    try {
      await loadDeferredLibrary(
        receive.loadLibrary,
        key: DeferredLibraryKeys.receive,
      );
    } catch (_) {
      // DeferredPage on the route will surface the error if load still fails.
    }
    if (!mounted) return;
    // Amount-first receive — wallet is chosen in-flow, never from home.
    await context.push('/receive');
  }

  void _openDepositForWallet(Wallet _) {
    // Platform has receive only — deposit entry points share the same flow.
    _openReceiveFlow();
  }

  void _openCreateWallet() {
    HapticFeedback.lightImpact();
    unawaited(_openCreateWalletFlow());
  }

  Future<void> _openCreateWalletFlow() async {
    await context.push<void>('/accounts');
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
    // Thin shell: navigation callbacks only. No wallet/history/price watches.
    // Each visual layer is an independent Consumer + RepaintBoundary
    // (see presentation/layers/home_layers.dart).
    void openStatement() {
      unawaited(context.push<void>('/activity'));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: homeBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: homeBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const HomeAuroraLayer(),
            const HomeRealtimeBootstrap(),
            const HomeEducationHost(),
            HomeScrollLayer(
              onRefresh: _refreshHomeData,
              onReceive: _openReceiveFlow,
              onSend: _openSend,
              onOpenStatement: openStatement,
              onOpenWallets: () => context.push('/accounts'),
              onCreateWallet: _openCreateWallet,
              onDepositWallet: _openDepositForWallet,
              onOpenDeposit: _openReceiveFlow,
              onOpenSendFromFeed: _openSend,
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

SliverToBoxAdapter sliverToBoxAdapterRepaint(Widget child) {
  return SliverToBoxAdapter(child: RepaintBoundary(child: child));
}
