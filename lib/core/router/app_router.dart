import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/features/auth/presentation/screens/welcome_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/home/presentation/screens/server_unavailable_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_loading_screen.dart';
import 'package:kerosene/features/home/presentation/screens/onboarding_steps_screen.dart';

import 'package:kerosene/features/home/presentation/screens/home_screen.dart' deferred as home;
import 'package:kerosene/features/security/presentation/screens/settings_screen.dart' deferred as settings;
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart' deferred as deposits;
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart' deferred as bitcoin_accounts;
import 'package:kerosene/features/movement/presentation/receive/receive_amount_entry_screen.dart' deferred as receive;
import 'package:kerosene/features/movement/presentation/send/send_money_screen.dart' deferred as send_money;

import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart' deferred as send_money_review;
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';

GoRouter buildAppRouter({
  required Widget Function(Widget child) privateRouteBuilder,
}) {
  return GoRouter(
    initialLocation: '/welcome',
    routes: [
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
      GoRoute(
        path: '/home_loading',
        builder: (context, state) => privateRouteBuilder(
          const HomeLoadingScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: home.loadLibrary,
            builder: (_) => home.HomeScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            builder: (_) => settings.SettingsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            builder: (_) => settings.SettingsScreen(openNotificationsPane: true),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: settings.loadLibrary,
            builder: (_) => settings.SettingsScreen(openSecurityPane: true),
          ),
        ),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: deposits.loadLibrary,
            builder: (_) => deposits.TransactionStatementScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: bitcoin_accounts.loadLibrary,
            builder: (_) => bitcoin_accounts.BitcoinAccountsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/receive',
        pageBuilder: (context, state) {
          return keroseneFlowSlideFromLeftPage<void>(
            key: state.pageKey,
            child: privateRouteBuilder(
              DeferredPage(
                loadLibrary: receive.loadLibrary,
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
      GoRoute(
        path: '/send-money',
        pageBuilder: (context, state) {
          return keroseneFlowSlidePage<void>(
            key: state.pageKey,
            child: privateRouteBuilder(
              DeferredPage(
                loadLibrary: send_money.loadLibrary,
                animateReveal: false,
                builder: (_) => const send_money.SendMoneyScreen(),
              ),
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'review',
            builder: (context, state) {
              final args = state.extra as InternalTransferReviewArgs<dynamic>;
              return privateRouteBuilder(
                DeferredPage(
                  loadLibrary: send_money_review.loadLibrary,
                  builder: (_) => send_money_review.InternalTransferReviewScreen<dynamic>(
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
              return CustomTransitionPage(
                key: state.pageKey,
                child: DeferredPage(
                  loadLibrary: send_money_review.loadLibrary,
                  builder: (_) => send_money_review.SendPaymentReceiptScreen<dynamic>(
                    data: args.data,
                    result: args.result,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 600),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
  );
}
