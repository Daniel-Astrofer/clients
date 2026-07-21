import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';

import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';
import 'package:kerosene/core/navigation/route_transition_observer.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/router/mobile_go_router.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../core/providers/appearance_provider.dart';
import '../core/providers/locale_provider.dart';
import '../core/providers/session_invalidation_provider.dart';
import '../core/utils/money_display.dart';
import '../core/responsive/kerosene_responsive.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/home/presentation/screens/home_loading_screen.dart';
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
import '../features/movement/presentation/hub/movement_hub_screen.dart'
    deferred as deposits;
import '../features/movement/presentation/send/send_money_screen.dart'
    deferred as send_money;
import '../core/providers/tor_providers.dart';
import '../core/providers/app_cold_start_provider.dart';
import '../core/services/tor_network_bootstrap.dart';
import '../core/services/tor_service.dart';
import '../core/performance/app_interaction_busy.dart';
import '../core/performance/graphics_runtime_degrade.dart';
import '../core/performance/kerosene_graphics_policy.dart';
import '../core/performance/kerosene_performance_boundary.dart';
import '../features/presentation/widgets/kerosene_logo_loading_view.dart';
import '../core/providers/shader_provider.dart';
import '../features/auth/controller/auth_controller.dart';
import '../core/utils/snackbar_helper.dart';
import '../features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import '../app/providers/price_alert_provider.dart';
import '../core/services/notification_delivery_bootstrap.dart';
import '../core/utils/native_screen_capture.dart';

/// Observes page transitions for [routeTransitionBusyProvider].
RouteTransitionBusyObserver? _routeTransitionBusyObserver;

Future<void> bootstrapMobile() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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

  // Log whether the in-app camera control will mount (Linux debug = on).
  ScreenCaptureConfig.logStatus();

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
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 ASYNC PLATFORM ERROR CAUGHT: $error');
    return true;
  };

  _routeTransitionBusyObserver = RouteTransitionBusyObserver(
    onBusyChanged: (busy) {
      Future.microtask(() {
        final notifier = container.read(routeTransitionBusyProvider.notifier);
        if (busy) {
          notifier.begin();
        } else {
          notifier.end();
        }
      });
    },
  );

  unawaited(_bootstrapTor(container));
  unawaited(_bootstrapPeripheralServices());
  unawaited(_bootstrapGraphics(container));
}

Future<void> _bootstrapGraphics(ProviderContainer container) async {
  // Image cache caps from static tier (not runtime-degraded flags).
  final policy = container.read(baseGraphicsPolicyProvider);
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      policy.maxImageCacheBytes;
  PaintingBinding.instance.imageCache.maximumSize = policy.maxImageCacheEntries;

  // Arm FrameTiming monitor (builds notifier + timings callback).
  container.read(graphicsRuntimeDegradeProvider);

  // Warm fragment programs + prefetch deferred libs after first frame so
  // navigation is not first-use of loadLibrary / SkSL on the gesture path.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        await container.read(homeAuroraShaderProvider.future);
      } catch (error, stack) {
        debugPrint('home aurora shader warm-up failed: $error\n$stack');
      }
      try {
        await container.read(metalShaderProvider.future);
      } catch (error, stack) {
        debugPrint('metal shader warm-up failed: $error\n$stack');
      }
      // Adjacent mobile surfaces — shared Future with DeferredPage.
      prefetchDeferredLibraries([
        home.loadLibrary,
        settings.loadLibrary,
        deposits.loadLibrary,
        bitcoin_accounts.loadLibrary,
        send_money.loadLibrary,
      ]);
    }());
  });
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router = buildMobileGoRouter(
    privateRouteBuilder: (child) => _PrivateMobileRoute(child: child),
    root: const _MobileAppRoot(),
    observers: mobileRouterObservers(
      transitionBusy: _routeTransitionBusyObserver,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).locale;
    final appearance = ref.watch(appearanceProvider);
    MoneyDisplay.bindAppLocale(locale);
    ref.listen<int>(sessionInvalidationProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      ref.read(authControllerProvider.notifier).markSessionInvalidated();
    });

    return MaterialApp.router(
      title: 'Kerosene',
      routerConfig: _router,
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
        current = _AppRealtimeBootstrap(child: current);
        return ScreenCaptureHost(child: current);
      },
    );
  }
}

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

    ref.listen<AppColdStartState>(appColdStartProvider, (previous, next) {
      if (!next.torSettled || previous?.torSettled == true) return;
      final auth = ref.read(authControllerProvider);
      if (auth is AuthServerUnavailable) {
        unawaited(
            ref.read(authControllerProvider.notifier).retrySessionCheck());
      }
    });

    if (!coldStart.canShowAppShell) {
      return const KeroseneLogoLoadingView(
        status: 'INICIANDO',
        detail: 'Preparando conexão segura',
      );
    }

    final authState = ref.watch(authControllerProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      return const KeroseneLogoLoadingView(
        status: 'INICIANDO',
        detail: 'Preparando conexão segura',
      );
    }

    if (authState is AuthAuthenticated) {
      if (!coldStart.torSettled && !AppEntryPinSession.unlocked) {
        return const KeroseneLogoLoadingView(
          status: 'INICIANDO',
          detail: 'Preparando conexão segura',
        );
      }
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
      final unlocked =
          ref.watch(appEntryPinUnlockedProvider) || AppEntryPinSession.unlocked;
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
