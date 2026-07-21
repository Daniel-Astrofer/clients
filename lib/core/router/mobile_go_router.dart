import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/navigation/app_route_observer.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/core/navigation/route_transition_observer.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/server_unavailable_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/welcome_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import 'package:kerosene/features/home/presentation/screens/home_loading_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    deferred as home;
import 'package:kerosene/features/home/presentation/screens/onboarding_steps_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart'
    deferred as deposits;
import 'package:kerosene/features/movement/presentation/receive/receive_amount_entry_screen.dart'
    deferred as receive;
import 'package:kerosene/features/movement/presentation/send/send_money_screen.dart'
    deferred as send_money;
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart'
    deferred as send_money_review;
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';
import 'package:kerosene/features/security/presentation/screens/settings_screen.dart'
    deferred as settings;

/// Global handle for non-BuildContext navigation (e.g. token interceptor).
GoRouter? keroseneGoRouter;

void keroseneGo(String location) {
  final router = keroseneGoRouter;
  if (router != null) {
    router.go(location);
    return;
  }
  SnackbarHelper.navigatorKey.currentState?.pushNamedAndRemoveUntil(
    location,
    (_) => false,
  );
}

GoRouter buildMobileGoRouter({
  required Widget Function(Widget child) privateRouteBuilder,
  required Widget root,
  List<NavigatorObserver> observers = const [],
}) {
  final router = GoRouter(
    navigatorKey: SnackbarHelper.navigatorKey,
    initialLocation: '/',
    observers: observers,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => root,
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/recovery/emergency',
        builder: (context, state) => const EmergencyRecoveryScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupFlowScreen(),
      ),
      GoRoute(
        path: '/server-unavailable',
        builder: (context, state) => const ServerUnavailableScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => privateRouteBuilder(
          _HomeFlowShell(overlay: child),
        ),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const SizedBox.shrink(),
            ),
          ),
          GoRoute(
            path: '/send-money',
            pageBuilder: (context, state) {
              final address = state.uri.queryParameters['address'];
              final amountRaw = state.uri.queryParameters['amount'];
              final amount =
                  amountRaw == null ? null : double.tryParse(amountRaw);
              final linkId = QrPaymentParser.extractPaymentLinkId(
                state.uri.toString(),
              );
              final initialAddress = address ??
                  (linkId == null
                      ? null
                      : QrPaymentParser.encodePaymentLink(linkId));
              return keroseneFlowSlidePage<void>(
                key: state.pageKey,
                child: DeferredPage(
                  loadLibrary: send_money.loadLibrary,
                  libraryKey: DeferredLibraryKeys.sendMoney,
                  animateReveal: false,
                  builder: (_) => send_money.SendMoneyScreen(
                    initialAddress: initialAddress,
                    initialAmountBtc: amount,
                  ),
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'review',
                builder: (context, state) {
                  final args =
                      state.extra as InternalTransferReviewArgs<dynamic>;
                  return privateRouteBuilder(
                    DeferredPage(
                      loadLibrary: send_money_review.loadLibrary,
                      libraryKey: DeferredLibraryKeys.sendMoneyReview,
                      builder: (_) => send_money_review
                          .InternalTransferReviewScreen<dynamic>(
                        title: args.title,
                        amountBtcLabel: args.amountBtcLabel,
                        fiatAmountLabel: args.fiatAmountLabel,
                        confirmLabel: args.confirmLabel,
                        submittingLabel: args.submittingLabel,
                        destinationLabel: args.destinationLabel,
                        networkLabel: args.networkLabel,
                        fromWalletLabel: args.fromWalletLabel,
                        rows: args.rows,
                        card: args.card,
                        requiresFirstSendAck: args.requiresFirstSendAck,
                        firstSendAddressPreview: args.firstSendAddressPreview,
                        firstSendAddress: args.firstSendAddress,
                        authNextStepLabel: args.authNextStepLabel,
                        onConfirm: args.onConfirm,
                        receiptBuilder: args.receiptBuilder,
                      ),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'receipt',
                pageBuilder: (context, state) {
                  final args = state.extra as SendPaymentReceiptArgs<dynamic>;
                  return CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: DeferredPage(
                      loadLibrary: send_money_review.loadLibrary,
                      libraryKey: DeferredLibraryKeys.sendMoneyReview,
                      builder: (_) =>
                          send_money_review.SendPaymentReceiptScreen<dynamic>(
                        data: args.data,
                        result: args.result,
                      ),
                    ),
                    transitionDuration: const Duration(milliseconds: 600),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return ClipPath(
                        clipper: CircularRevealClipper(
                          fraction: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ).value,
                        ),
                        child: child,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/home_loading',
        builder: (context, state) => privateRouteBuilder(
          const HomeLoadingScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            libraryKey: DeferredLibraryKeys.settings,
            builder: (_) => settings.SettingsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            libraryKey: DeferredLibraryKeys.settings,
            builder: (_) => settings.SettingsScreen(
              openNotificationsPane: true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            libraryKey: DeferredLibraryKeys.settings,
            builder: (_) => settings.SettingsScreen(
              openSecurityPane: true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: deposits.loadLibrary,
            libraryKey: DeferredLibraryKeys.deposits,
            builder: (_) => deposits.TransactionStatementScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: bitcoin_accounts.loadLibrary,
            libraryKey: DeferredLibraryKeys.bitcoinAccounts,
            builder: (_) => bitcoin_accounts.BitcoinAccountsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/receive',
        pageBuilder: (context, state) {
          // Same proven slide as send — avoid custom Offset(-1) + deferred fade
          // stacking that left a black frame while the library loaded.
          return keroseneFlowSlideFromLeftPage<void>(
            key: state.pageKey,
            child: privateRouteBuilder(
              DeferredPage(
                loadLibrary: receive.loadLibrary,
                libraryKey: DeferredLibraryKeys.receive,
                animateReveal: false,
                builder: (_) => receive.ReceiveAmountEntryScreen(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/onboarding/steps',
        builder: (context, state) => privateRouteBuilder(
          const OnboardingStepsScreen(),
        ),
      ),
    ],
  );
  keroseneGoRouter = router;
  return router;
}

/// Home stays mounted under send overlays (go-only navigation).
///
/// Performance: pauses home tickers while send is open; ignores the empty shell
/// navigator on `/home` so Linux/desktop taps reach the home layer.
class _HomeFlowShell extends StatelessWidget {
  final Widget overlay;

  const _HomeFlowShell({required this.overlay});

  static bool _sendOverlayActive(String path) {
    return path.startsWith('/send-money');
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final overlayActive = _sendOverlayActive(path);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: TickerMode(
            enabled: !overlayActive,
            child: IgnorePointer(
              ignoring: overlayActive,
              child: DeferredPage(
                loadLibrary: home.loadLibrary,
                libraryKey: DeferredLibraryKeys.home,
                builder: (_) => home.HomeScreen(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !overlayActive,
            child: overlay,
          ),
        ),
      ],
    );
  }
}

/// Convenience for typed observer lists from bootstrap.
List<NavigatorObserver> mobileRouterObservers({
  RouteTransitionBusyObserver? transitionBusy,
}) {
  return [
    appRouteObserver,
    if (transitionBusy != null) transitionBusy,
  ];
}
