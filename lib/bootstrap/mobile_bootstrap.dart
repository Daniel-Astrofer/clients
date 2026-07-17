import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/theme/app_theme.dart';

import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../core/providers/appearance_provider.dart';
import '../core/providers/locale_provider.dart';
import '../core/providers/session_invalidation_provider.dart';
import '../core/utils/money_display.dart';
import '../core/responsive/kerosene_responsive.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/presentation/screens/emergency_recovery_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup/signup_flow_screen.dart';
import '../features/home/presentation/screens/home_loading_screen.dart';
import '../features/home/presentation/screens/onboarding_steps_screen.dart';
import '../features/auth/presentation/screens/server_unavailable_screen.dart';
import '../features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import '../features/home/presentation/screens/home_screen.dart'
    deferred as home;
import '../features/security/presentation/providers/security_provider.dart';
import '../features/security/presentation/widgets/app_entry_pin_gate.dart';
import '../features/security/presentation/screens/settings_screen.dart'
    deferred as settings;
import '../features/notifications/presentation/widgets/global_notification_host.dart';
import '../core/services/background_service.dart';
import '../core/services/notification_service.dart' as local_notifications;
import '../features/movement/screens/movement_hub_screen.dart'
    deferred as deposits;
import '../features/financial_accounts/domain/entities/wallet.dart';
import '../features/movement/screens/send_money_screen.dart'
    deferred as send_money;
import '../features/financial_accounts/presentation/widgets/wallet_flow_selector.dart';
import '../core/providers/tor_providers.dart';
import '../core/providers/app_cold_start_provider.dart';
import '../core/services/tor_network_bootstrap.dart';
import '../core/services/tor_service.dart';
import '../core/performance/kerosene_performance_boundary.dart';
import '../core/presentation/widgets/kerosene_logo_loading_view.dart';
import '../core/utils/qr_payment_parser.dart';
import '../features/auth/controller/auth_controller.dart';
import '../core/utils/snackbar_helper.dart';
import '../features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import '../app/providers/price_alert_provider.dart';
import '../core/services/notification_delivery_bootstrap.dart';

Future<void> bootstrapMobile() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make dual Linux profiles obvious in logs (primary_ vs secondary_).
  if (kDebugMode) {
    debugPrint(
      '[kero] profile=${keroseneProfileLabel()} '
      'secure_prefix=${keroseneSecurePrefix()} '
      'tag=${keroseneProfileTag()}',
    );
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
  );

  await initializeApp(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: buildApp(),
    ),
  );
}

Future<void> initializeApp(ProviderContainer container) async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 GLOBAL FLUTTER ERROR CAUGHT: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 ASYNC PLATFORM ERROR CAUGHT: $error');
    return true;
  };

  unawaited(_bootstrapTor(container));
  unawaited(_bootstrapPeripheralServices());

  PaintingBinding.instance.imageCache.maximumSizeBytes = 500 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 300;
}

Future<void> _bootstrapTor(ProviderContainer container) async {
  await bootstrapTorNetwork(
    torService: TorService.instance,
    updateApiUrl: (url) {
      container.read(torApiUrlProvider.notifier).updateUrl(url);
    },
  );
}

Future<void> _bootstrapPeripheralServices() async {
  try {
    final notif = local_notifications.NotificationService();
    // Tap on system shade → navigate via app navigator.
    notif.onNotificationTap = (payload) {
      final route = payload.trim();
      if (route.isEmpty) return;
      final nav = SnackbarHelper.navigatorKey.currentState;
      if (nav == null) return;
      try {
        // Absolute path deeplinks from backend (e.g. /home, /settings/security).
        if (route.startsWith('/')) {
          unawaited(nav.pushNamed(route));
        }
      } catch (e) {
        debugPrint('Notification tap navigation failed for "$route": $e');
      }
    };
    await notif.init();
    await initializeBackgroundService();
  } catch (error) {
    debugPrint('Peripheral service bootstrap failed: $error');
  }
}

Widget buildApp() => const MyApp();

/// First shell: brand K beat, then auth shell.
///
/// Returning users: K → PIN (stable pad; Tor may still boot) → dots → Home.
/// Tor readiness is gated inside PIN verify + HomeLoadingScreen requests.
///
/// Important: only one [AppEntryPinGate] on the home path. Route wrappers use
/// [appEntryPinUnlockedProvider] and must not remount a second gate that
/// re-asks for PIN after unlock.
class _MobileAppRoot extends ConsumerWidget {
  const _MobileAppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coldStart = ref.watch(appColdStartProvider);

    // Session probe may fail while Tor is still binding — retry once Tor is up.
    ref.listen<AppColdStartState>(appColdStartProvider, (previous, next) {
      if (!next.torSettled || previous?.torSettled == true) return;
      final auth = ref.read(authControllerProvider);
      if (auth is AuthServerUnavailable) {
        unawaited(ref.read(authControllerProvider.notifier).retrySessionCheck());
      }
    });

    // 1) Kerosene K — brand beat while auth probes.
    if (!coldStart.canShowAppShell) {
      return const KeroseneLogoLoadingView(
        status: 'INICIANDO',
        detail: 'Preparando conexão segura',
      );
    }

    final authState = ref.watch(authControllerProvider);

    // Stay on K until session restore finishes — never flash PIN then Welcome.
    if (authState is AuthInitial || authState is AuthLoading) {
      return const KeroseneLogoLoadingView(
        status: 'INICIANDO',
        detail: 'Preparando conexão segura',
      );
    }

    if (authState is AuthAuthenticated) {
      // Token login: wait for Tor **before** the PIN pad.
      // Showing PIN while Tor is still binding, then rebuilding when Tor
      // settles, re-asked the PIN (double entry). Hold the K logo until the
      // relay is up, then one unlock pad.
      if (!coldStart.torSettled && !AppEntryPinSession.unlocked) {
        return const KeroseneLogoLoadingView(
          status: 'INICIANDO',
          detail: 'Preparando conexão segura',
        );
      }
      // Single PIN gate. Unlocked → HomeLoadingScreen → Home.
      return const AppEntryPinGate(
        child: HomeLoadingScreen(),
      );
    }

    if (authState is AuthServerUnavailable) {
      if (!coldStart.torSettled) {
        return const KeroseneLogoLoadingView(
          status: 'INICIANDO',
          detail: 'Preparando conexão segura',
        );
      }
      return const ServerUnavailableScreen();
    }

    return const WelcomeScreen();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).locale;
    final appearance = ref.watch(appearanceProvider);
    // Keep number formatting (thousands/decimals) in sync with app language
    // for every MoneyDisplay call site, including pure helpers.
    MoneyDisplay.bindAppLocale(locale);
    ref.listen<int>(sessionInvalidationProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      ref.read(authControllerProvider.notifier).markSessionInvalidated();
    });

    return MaterialApp(
      title: 'Kerosene',
      navigatorKey: SnackbarHelper.navigatorKey,
      scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const KeroseneScrollBehavior(),
      theme: AppTheme.themeFor(appearance.themeVariant),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first;
      },
      builder: (context, child) {
        Widget current = KerosenePerformanceBoundary(
          child: ServerAvailabilityGate(
            child: child ?? const SizedBox.shrink(),
          ),
        );
        current = KeroseneResponsiveBoundary(
          child: current,
        );
        current = GlobalNotificationHost(child: current);
        return _AppRealtimeBootstrap(child: current);
      },
      home: const _MobileAppRoot(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/recovery/emergency': (context) => const EmergencyRecoveryScreen(),
        '/signup': (context) => const SignupFlowScreen(),
        '/server-unavailable': (context) => const ServerUnavailableScreen(),
        '/home': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: home.loadLibrary,
                builder: (_) => home.HomeScreen(),
              ),
            ),
        '/home_loading': (context) => const _PrivateMobileRoute(
              child: HomeLoadingScreen(),
            ),
        '/settings': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: settings.loadLibrary,
                builder: (_) => settings.SettingsScreen(),
              ),
            ),
        '/settings/notifications': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: settings.loadLibrary,
                builder: (_) => settings.SettingsScreen(
                  openNotificationsPane: true,
                ),
              ),
            ),
        '/settings/security': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: settings.loadLibrary,
                builder: (_) => settings.SettingsScreen(
                  openSecurityPane: true,
                ),
              ),
            ),
        '/activity': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: deposits.loadLibrary,
                builder: (_) => deposits.TransactionStatementScreen(),
              ),
            ),
        '/accounts': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: bitcoin_accounts.loadLibrary,
                builder: (_) => bitcoin_accounts.BitcoinAccountsScreen(),
              ),
            ),
        '/receive': (context) => _PrivateMobileRoute(
              child: DeferredPage(
                loadLibrary: deposits.loadLibrary,
                builder: (_) => deposits.MovementHubScreen(),
              ),
            ),
        '/onboarding/steps': (context) => const _PrivateMobileRoute(
              child: OnboardingStepsScreen(),
            ),
        '/send-money': (context) => _PrivateMobileRoute(
              child: _WalletFlowMobileRoute(
                titleBuilder: (context) => context.tr.send,
                subtitleBuilder: (context) =>
                    context.tr.walletSelectorSendSubtitle,
                destinationBuilder: (wallet) => DeferredPage(
                  loadLibrary: send_money.loadLibrary,
                  builder: (_) => send_money.SendMoneyScreen(
                    walletId: wallet.id,
                  ),
                ),
              ),
            ),
      },
      onGenerateRoute: (settings) {
        final linkId = QrPaymentParser.extractPaymentLinkId(
          settings.name ?? '',
        );
        if (linkId != null) {
          return keroseneHorizontalRoute(
            settings: settings,
            builder: (_) => _PrivateMobileRoute(
              child: _WalletFlowMobileRoute(
                titleBuilder: (context) => context.tr.send,
                subtitleBuilder: (context) =>
                    context.tr.walletSelectorSendSubtitle,
                destinationBuilder: (wallet) => DeferredPage(
                  loadLibrary: send_money.loadLibrary,
                  builder: (_) => send_money.SendMoneyScreen(
                    walletId: wallet.id,
                    initialAddress: QrPaymentParser.encodePaymentLink(linkId),
                  ),
                ),
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}

class _WalletFlowMobileRoute extends StatelessWidget {
  final String Function(BuildContext context) titleBuilder;
  final String Function(BuildContext context) subtitleBuilder;
  final Widget Function(Wallet wallet) destinationBuilder;

  const _WalletFlowMobileRoute({
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.destinationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return WalletFlowSelector(
      title: titleBuilder(context),
      subtitle: subtitleBuilder(context),
      onContinue: (wallet) {
        Navigator.of(context).pushReplacement<void, void>(
          keroseneHorizontalRoute<void>(
            builder: (_) => destinationBuilder(wallet),
          ),
        );
      },
    );
  }
}

class _PrivateMobileRoute extends ConsumerWidget {
  final Widget child;

  const _PrivateMobileRoute({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is AuthInitial || authState is AuthLoading) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    if (authState is AuthAuthenticated) {
      // Never mount a second [AppEntryPinGate] after cold-start unlock.
      final unlocked = ref.watch(appEntryPinUnlockedProvider) ||
          AppEntryPinSession.unlocked;
      if (unlocked) {
        if (!ref.read(appEntryPinUnlockedProvider)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (AppEntryPinSession.unlocked) {
              ref.read(appEntryPinUnlockedProvider.notifier).unlock();
            }
          });
        }
        return child;
      }
      // Same Tor gate as cold start: do not show PIN until the relay is up.
      final torSettled = ref.watch(torSettledProvider);
      if (!torSettled) {
        return const KeroseneLogoLoadingView(
          status: 'INICIANDO',
          detail: 'Preparando conexão segura',
        );
      }
      return AppEntryPinGate(child: child);
    }
    if (authState is AuthServerUnavailable) {
      return const ServerUnavailableScreen();
    }
    return const WelcomeScreen();
  }
}

class _AppRealtimeBootstrap extends ConsumerStatefulWidget {
  final Widget child;

  const _AppRealtimeBootstrap({required this.child});

  @override
  ConsumerState<_AppRealtimeBootstrap> createState() =>
      _AppRealtimeBootstrapState();
}

class _AppRealtimeBootstrapState extends ConsumerState<_AppRealtimeBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _applyLifecycle(lifecycle);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      // Pull balance/extrato if WS marked dirty while backgrounded.
      unawaited(refreshFinancialProjectionIfDirty(ref));
    }
  }

  void _applyLifecycle(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    ref.read(appForegroundProvider.notifier).setForeground(foreground);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    // Use synchronous gate status — never wait on Tor/network for realtime boot.
    final gateStatus = ref.watch(appPinGateStatusProvider);
    final appUnlocked = ref.watch(appEntryPinUnlockedProvider);
    final appPinSatisfied = !gateStatus.requiresGate || appUnlocked;
    if (authState is AuthAuthenticated && appPinSatisfied) {
      ref.watch(balanceWebSocketServiceProvider);
      // Trigger market-price alert notifications (BTC up/down X%).
      ref.watch(priceAlertProvider);
      // Permissions + channels + background poll + device token registry.
      unawaited(
        ref.read(notificationDeliveryBootstrapProvider).ensureReady(),
      );
    }
    return widget.child;
  }
}

class KeroseneScrollBehavior extends ScrollBehavior {
  const KeroseneScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
