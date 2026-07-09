import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/navigation/deferred_page.dart';

import 'package:kerosene/core/presentation/widgets/kerosene_logo_loading_view.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    deferred as home;
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';

class HomeLoadingScreen extends ConsumerStatefulWidget {
  const HomeLoadingScreen({super.key});

  @override
  ConsumerState<HomeLoadingScreen> createState() => _HomeLoadingScreenState();
}

class _HomeLoadingScreenState extends ConsumerState<HomeLoadingScreen> {
  double _uIsDelayed = 0.0;
  Timer? _timeoutTimer;
  Timer? _minDurationTimer;
  Timer? _walletRetryTimer;
  Timer? _sessionReadyRetryTimer;
  bool _isNavigating = false;
  bool _minDurationPassed = false;
  bool _hasError = false;
  String _errorMessage = "";
  bool _walletSetupRedirectAttempted = false;
  bool _initialLoadStarted = false;
  int _walletRetryAttempt = 0;
  int _sessionReadyRetryAttempt = 0;
  static const int _maxWalletRetryAttempts = 3;
  static const int _maxSessionReadyRetryAttempts = 20;

  @override
  void initState() {
    super.initState();
    _minDurationTimer = Timer(KeroseneMotion.loadingMinimum, () {
      if (mounted) setState(() => _minDurationPassed = true);
    });

    _timeoutTimer = Timer(KeroseneMotion.loadingTimeout, () {
      if (mounted && !_hasError) {
        setState(() {
          _uIsDelayed = 1.0;
        });
      }
    });

    // Trigger wallet loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startInitialLoadWhenSessionReady());
    });
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _timeoutTimer?.cancel();
    _walletRetryTimer?.cancel();
    _sessionReadyRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _startInitialLoadWhenSessionReady() async {
    if (_initialLoadStarted || !mounted) return;

    final authState = ref.read(authControllerProvider);
    final sessionScope = ref.read(sessionStorageScopeProvider);
    if (authState is! AuthAuthenticated || sessionScope == null) {
      _scheduleSessionReadyRetry();
      return;
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
      _navigateToHome(allowError: true);
      return;
    }

    final delay = switch (_walletRetryAttempt) {
      0 => KeroseneMotion.loadingMinimum,
      1 => KeroseneMotion.loadingRetryMedium,
      _ => KeroseneMotion.loadingRetryLong,
    };
    _walletRetryAttempt += 1;

    _walletRetryTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
      if (_initialLoadStarted) {
        ref.read(walletProvider.notifier).refresh();
        ref.invalidate(transactionHistoryProvider);
      } else {
        unawaited(_startInitialLoadWhenSessionReady());
      }
    });
  }

  void _navigateToHome({bool allowError = false}) {
    if (_isNavigating || (_hasError && !allowError)) return;
    _isNavigating = true;
    _timeoutTimer?.cancel();

    Future.delayed(KeroseneMotion.slow, () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                DeferredPage(
              loadLibrary: home.loadLibrary,
              builder: (_) => home.HomeScreen(),
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: KeroseneMotion.calm,
          ),
          (route) => false,
        );
      }
    });
  }

  Future<void> _navigateToWalletSetup(String? userId) async {
    if (_isNavigating || _hasError || _walletSetupRedirectAttempted) return;
    _isNavigating = true;
    _walletSetupRedirectAttempted = true;
    _timeoutTimer?.cancel();

    _markWalletSetupRedirectSeen(userId);

    await Future<void>.delayed(KeroseneMotion.slow);
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => DeferredPage(
          loadLibrary: bitcoin_accounts.loadLibrary,
          builder: (_) => bitcoin_accounts.BitcoinAccountsScreen(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: KeroseneMotion.long,
      ),
    );

    if (!mounted) return;
    await ref.read(walletProvider.notifier).refresh();
    ref.invalidate(transactionHistoryProvider);

    _isNavigating = false;
    _navigateToHome();
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
    final authState = ref.watch(authControllerProvider);
    final authenticatedUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthAuthenticated) {
        unawaited(_startInitialLoadWhenSessionReady());
      }
    });

    ref.listen<WalletState>(walletProvider, (_, next) {
      if (next is WalletError) {
        if (mounted) {
          setState(() {
            _uIsDelayed = 1.0;
            _hasError = true;
            _errorMessage = next.message;
          });
        }
        if (next.isRetryable) {
          _scheduleWalletRetry();
        } else {
          _walletRetryTimer?.cancel();
        }
        return;
      }

      if (next is WalletLoaded) {
        _walletRetryTimer?.cancel();
        _walletRetryAttempt = 0;
        if (mounted && (_hasError || _uIsDelayed > 0.0)) {
          setState(() {
            _uIsDelayed = 0.0;
            _hasError = false;
            _errorMessage = '';
          });
        }
      }
    });

    // Only move away if data is loaded AND minimum animation time completed
    if (walletState is WalletLoaded &&
        _uIsDelayed == 0.0 &&
        _minDurationPassed &&
        !_hasError) {
      if (walletState.wallets.isEmpty &&
          !_hasSeenWalletSetupRedirect(authenticatedUserId)) {
        unawaited(_navigateToWalletSetup(authenticatedUserId));
      } else {
        _navigateToHome();
      }
    }

    if (walletState is WalletError &&
        (!walletState.isRetryable ||
            _walletRetryAttempt >= _maxWalletRetryAttempts) &&
        _minDurationPassed) {
      _navigateToHome(allowError: true);
    }

    return KeroseneLogoLoadingView(
      status: _hasError
          ? 'CONEXÃO INDISPONÍVEL'
          : (_uIsDelayed > 0.5 ? 'CONEXÃO LENTA' : 'SINCRONIZANDO'),
      detail: _hasError
          ? 'Sessão preservada. Tentando reconectar...'
          : (_uIsDelayed > 0.5
              ? 'Tentando carregar seus dados...'
              : 'Garantindo segurança total para seus ativos'),
      isDelayed: _uIsDelayed > 0.5,
      isError: _hasError,
      errorMessage: _errorMessage,
    );
  }
}
