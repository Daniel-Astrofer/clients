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
import 'package:kerosene/features/movement/screens/statement_screen.dart' deferred as deposits;
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart' deferred as bitcoin_accounts;
import 'package:kerosene/features/movement/screens/movement_hub_screen.dart' deferred as receive;
import 'package:kerosene/features/movement/screens/send_money_screen.dart' deferred as send_money;

import 'package:kerosene/core/presentation/widgets/deferred_page.dart';
import 'package:kerosene/features/financial_accounts/domain/wallet.dart';

GoRouter buildAppRouter({
  required Widget Function(Widget child) privateRouteBuilder,
  required Widget Function(
    String Function(BuildContext) titleBuilder,
    String Function(BuildContext) subtitleBuilder,
    Widget Function(Wallet) destinationBuilder,
  ) walletFlowBuilder,
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
        builder: (context, state) => privateRouteBuilder(
          DeferredPage(
            loadLibrary: receive.loadLibrary,
            builder: (_) => receive.MovementHubScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding/steps',
        builder: (context, state) => privateRouteBuilder(
          const OnboardingStepsScreen(),
        ),
      ),
      GoRoute(
        path: '/send-money',
        builder: (context, state) {
          final walletId = state.extra as String?;
          return privateRouteBuilder(
            walletFlowBuilder(
              (context) => "Enviar", 
              (context) => "Selecione a carteira de envio", 
              (wallet) => DeferredPage(
                loadLibrary: send_money.loadLibrary,
                builder: (_) => send_money.SendMoneyScreen(walletId: wallet.id),
              ),
            ),
          );
        },
      ),
    ],
  );
}
