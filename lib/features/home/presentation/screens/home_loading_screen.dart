import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kerosene/features/presentation/widgets/tor_navigation_loading_screen.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    deferred as home;
import 'package:kerosene/features/movement/presentation/send/send_money_screen.dart'
    deferred as send_money;
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';

/// Single post-PIN loading surface: Tor dots only.
///
/// Loads home data (wallets/history) and the deferred home library under the
/// same dots screen, then jumps straight to [HomeScreen] with no extra spinner.
class HomeLoadingScreen extends ConsumerStatefulWidget {
  const HomeLoadingScreen({super.key});

  @override
  ConsumerState<HomeLoadingScreen> createState() => _HomeLoadingScreenState();
}

class _HomeLoadingScreenState extends ConsumerState<HomeLoadingScreen> {
  Timer? _timeoutTimer;
  Timer? _walletRetryTimer;
  Timer? _sessionReadyRetryTimer;
  bool _isNavigating = false;
  bool _hasError = false;
  bool _walletSetupRedirectAttempted = false;
  bool _initialLoadStarted = false;
  bool _homeLibraryReady = false;
  int _walletRetryAttempt = 0;
  int _sessionReadyRetryAttempt = 0;
  static const int _maxWalletRetryAttempts = 3;
  static const int _maxSessionReadyRetryAttempts = 20;

  @override
  void initState() {
    super.initState();

    // Preload home + send while dots are up so first Enviar never loads mid-slide.
    unawaited(_preloadHomeLibrary());
    unawaited(loadDeferredLibrary(
      send_money.loadLibrary,
      key: DeferredLibraryKeys.sendMoney,
    ));

    _timeoutTimer = Timer(KeroseneMotion.loadingTimeout, () {
      if (mounted && !_hasError && !_isNavigating) {
        // Soft timeout: still try to enter home rather than stack more loaders.
        unawaited(_navigateToHome(allowError: true));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startInitialLoadWhenSessionReady());
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _walletRetryTimer?.cancel();
    _sessionReadyRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _preloadHomeLibrary() async {
    try {
      await home.loadLibrary();
    } catch (_) {
      // Navigation path will retry loadLibrary if needed.
    }
    if (mounted) {
      setState(() => _homeLibraryReady = true);
      _tryFinish();
    }
  }

  Future<void> _startInitialLoadWhenSessionReady() async {
    if (_initialLoadStarted || !mounted) return;

    final authState = ref.read(authControllerProvider);
    final sessionScope = ref.read(sessionStorageScopeProvider);
    if (authState is! AuthAuthenticated || sessionScope == null) {
      _scheduleSessionReadyRetry();
      return;
    }

    // PIN may unlock before Tor finishes; hold wallet requests until relay is up.
    if (!ref.read(torSettledProvider)) {
      await ref.read(appColdStartProvider.notifier).waitUntilTorSettled();
      if (!mounted || _initialLoadStarted) return;
    }

    final token = await ref.read(authLocalDataSourceProvider).getToken();
    if (!mounted || _initialLoadStarted) return;
    if (!_isUsableJwt(token)) {
      _scheduleSessionReadyRetry();
      return;
    }

    _initialLoadStarted = true;
    _sessionReadyRetryTimer?.cancel();
    _sessionReadyRetryTimer = null;
    ref.read(walletProvider.notifier).refresh();
    ref.invalidate(transactionHistoryProvider);
  }

  bool _isUsableJwt(String? token) {
    final value = token?.trim();
    return value != null && value.isNotEmpty && value.contains('.');
  }

  void _scheduleSessionReadyRetry() {
    if (!mounted ||
        _initialLoadStarted ||
        (_sessionReadyRetryTimer?.isActive ?? false)) {
      return;
    }

    if (_sessionReadyRetryAttempt >= _maxSessionReadyRetryAttempts) {
      unawaited(ref.read(authControllerProvider.notifier).retrySessionCheck());
      return;
    }

    final delay = _sessionReadyRetryAttempt < 8
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 750);
    _sessionReadyRetryAttempt += 1;
    _sessionReadyRetryTimer = Timer(delay, () {
      if (!mounted) return;
      unawaited(_startInitialLoadWhenSessionReady());
    });
  }

  void _scheduleWalletRetry() {
    if (_walletRetryTimer?.isActive ?? false) {
      return;
    }

    if (_walletRetryAttempt >= _maxWalletRetryAttempts) {
      _walletRetryTimer?.cancel();
      unawaited(_navigateToHome(allowError: true));
      return;
    }

    final delay = switch (_walletRetryAttempt) {
      0 => KeroseneMotion.short,
      1 => KeroseneMotion.medium,
      _ => KeroseneMotion.long,
    };
    _walletRetryAttempt += 1;

    _walletRetryTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _hasError = false;
      });
      if (_initialLoadStarted) {
        ref.read(walletProvider.notifier).refresh();
        ref.invalidate(transactionHistoryProvider);
      } else {
        unawaited(_startInitialLoadWhenSessionReady());
      }
    });
  }

  void _tryFinish() {
    if (_isNavigating || !mounted) return;

    final walletState = ref.read(walletProvider);
    final authState = ref.read(authControllerProvider);
    final authenticatedUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    if (walletState is WalletLoaded && !_hasError && _homeLibraryReady) {
      if (walletState.wallets.isEmpty &&
          !_hasSeenWalletSetupRedirect(authenticatedUserId)) {
        unawaited(_navigateToWalletSetup(authenticatedUserId));
      } else {
        unawaited(_navigateToHome());
      }
      return;
    }

    if (walletState is WalletError &&
        (!walletState.isRetryable ||
            _walletRetryAttempt >= _maxWalletRetryAttempts) &&
        _homeLibraryReady) {
      unawaited(_navigateToHome(allowError: true));
    }
  }

  Future<void> _navigateToHome({bool allowError = false}) async {
    if (_isNavigating || (_hasError && !allowError)) return;
    _isNavigating = true;
    _timeoutTimer?.cancel();

    try {
      if (!_homeLibraryReady) {
        await home.loadLibrary();
        _homeLibraryReady = true;
      }
    } catch (_) {
      // Fall through; HomeScreen may still fail to build — better than looping loaders.
    }

    if (!mounted) return;

    context.go('/home');
  }

  Future<void> _navigateToWalletSetup(String? userId) async {
    if (_isNavigating || _hasError || _walletSetupRedirectAttempted) return;
    _isNavigating = true;
    _walletSetupRedirectAttempted = true;
    _timeoutTimer?.cancel();

    _markWalletSetupRedirectSeen(userId);

    if (!mounted) return;

    try {
      await bitcoin_accounts.loadLibrary();
    } catch (_) {}

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            bitcoin_accounts.BitcoinAccountsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: KeroseneMotion.short,
      ),
    );

    if (!mounted) return;
    await ref.read(walletProvider.notifier).refresh();
    ref.invalidate(transactionHistoryProvider);

    _isNavigating = false;
    unawaited(_navigateToHome());
  }

  bool _hasSeenWalletSetupRedirect(String? userId) {
    if (userId == null || userId.isEmpty) {
      return false;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_walletSetupRedirectKey(userId)) ?? false;
  }

  void _markWalletSetupRedirectSeen(String? userId) {
    if (userId == null || userId.isEmpty) {
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(prefs.setBool(_walletSetupRedirectKey(userId), true));
  }

  String _walletSetupRedirectKey(String userId) =>
      'home.wallet_setup_redirect_seen.$userId';

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthAuthenticated) {
        unawaited(_startInitialLoadWhenSessionReady());
      }
    });

    ref.listen<WalletState>(walletProvider, (_, next) {
      if (next is WalletError) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        if (next.isRetryable) {
          _scheduleWalletRetry();
        } else {
          _walletRetryTimer?.cancel();
          _tryFinish();
        }
        return;
      }

      if (next is WalletLoaded) {
        _walletRetryTimer?.cancel();
        _walletRetryAttempt = 0;
        if (mounted && _hasError) {
          setState(() {
            _hasError = false;
          });
        }
        _tryFinish();
      }
    });

    // Also evaluate when library becomes ready while wallets already loaded.
    if (walletState is WalletLoaded || walletState is WalletError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryFinish();
      });
    }

    return const TorNavigationLoadingScreen();
  }
}
