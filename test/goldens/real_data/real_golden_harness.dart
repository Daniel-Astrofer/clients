import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/biometric_provider.dart';
import 'package:kerosene/core/providers/locale_provider.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart'
    show AccountSecurityStatusResult, BackupCodesStatusResult;
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/presentation/providers/home_balance_ceremony_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_feed_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/movement/data/entities/deposit.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';

import '../../support/real_api_snapshot.dart';

/// Phone width (logical px). Height expands with scroll content.
const realGoldenPhoneWidth = 390.0;
const realGoldenMinHeight = 844.0;
const realGoldenMaxHeight = 12000.0;

late SharedPreferences realGoldenPrefs;
late RealUiSnapshot realGoldenSnapshot;

/// Set by [tools/device-snapshot-goldens.sh].
const runRealGoldens = bool.fromEnvironment('RUN_REAL_GOLDENS');

bool get shouldRunRealGoldens {
  // Script always passes RUN_REAL_GOLDENS=true after placing the fixture.
  if (runRealGoldens) return true;
  return resolveDeviceSnapshotFile() != null;
}

Future<void> initializeRealGoldenHarness() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await loadAppFonts();

  SharedPreferences.setMockInitialValues(const {});
  FlutterSecureStorage.setMockInitialValues({});
  realGoldenPrefs = await SharedPreferences.getInstance();

  final fromDevice = loadDeviceUiSnapshot();
  if (fromDevice != null) {
    realGoldenSnapshot = fromDevice;
    // ignore: avoid_print
    print(
      '[real-golden] snapshot user=${fromDevice.user.username} '
      'wallets=${fromDevice.wallets.length} txs=${fromDevice.transactions.length}',
    );
    return;
  }

  if (runRealGoldens) {
    throw StateError(
      'RUN_REAL_GOLDENS=true mas device_ui_snapshot.json não encontrado.\n'
      '1) No app logado, toque DADOS (exporta JSON)\n'
      '2) bash tools/device-snapshot-goldens.sh\n'
      'Ou: DEVICE_SNAPSHOT_PATH=/path/to/device_ui_snapshot.json',
    );
  }

  realGoldenSnapshot = RealUiSnapshot(
    user: mockUser,
    jwt: '',
    apiBaseUrl: '',
    wallets: mockWallets,
    transactions: mockTransactions,
    rates: const BackendBtcRates(
      btcUsd: 67234.5,
      btcBrl: 336172.5,
      btcEur: 62109.0,
      usdBrl: 5.0,
    ),
    capturedAt: DateTime.utc(2026, 1, 1),
    source: 'placeholder',
  );
}

Future<void> pumpRealFullScrollGolden(
  WidgetTester tester,
  Widget child, {
  double width = realGoldenPhoneWidth,
  double minHeight = realGoldenMinHeight,
  double maxHeight = realGoldenMaxHeight,
}) async {
  // Start at phone viewport so maxScrollExtent reflects remaining content.
  // (If we start at 5000px height, extent is 0 and the PNG is mostly black.)
  await tester.binding.setSurfaceSize(Size(width, minHeight));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    wrapRealGolden(
      TickerMode(enabled: false, child: child),
    ),
  );

  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }

  var maxExtent = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final pos = state.position;
    if (pos.maxScrollExtent > maxExtent) {
      maxExtent = pos.maxScrollExtent;
    }
  }

  final contentHeight =
      (minHeight + maxExtent + 48).clamp(minHeight, maxHeight);

  await tester.binding.setSurfaceSize(Size(width, contentHeight));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Frozen providers from device snapshot — **no network** during paint.
Widget wrapRealGolden(Widget child) {
  final snap = realGoldenSnapshot;
  final rate = snap.rates.btcUsd > 0 ? snap.rates.btcUsd : 67234.5;
  final brl = snap.rates.btcBrl > 0 ? snap.rates.btcBrl : rate * 5;
  final eur = snap.rates.btcEur > 0 ? snap.rates.btcEur : rate * 0.92;

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(realGoldenPrefs),
      networkStatusProvider.overrideWith(() => NetworkStatusNotifier()),
      bitcoinAccountsServiceProvider
          .overrideWithValue(MockBitcoinAccountsService()),
      bitcoinAccountsProvider.overrideWith(BitcoinAccountsNotifier.new),
      sovereigntyStatusProvider.overrideWith((ref) async => mockSecurityStatus),
      kfeReserveOverviewProvider
          .overrideWith((ref) async => mockKfeReserveOverview),
      auditStatsProvider.overrideWith((ref) async => mockSecurityAuditStats),
      accountSecurityProfileProvider
          .overrideWith((ref) async => mockAccountSecurityProfile),
      appPinStatusProvider.overrideWith((ref) async => mockAppPinStatus),
      adminKeyStatusProvider.overrideWith((ref) async => mockAdminKeyStatus),
      pendingAdminAccessAttemptsProvider
          .overrideWith((ref) async => mockAdminAccessAttempts),
      adminAuthenticatedDevicesProvider
          .overrideWith((ref) async => mockAdminDevices),
      appearanceProvider.overrideWith(() => _RealAppearanceNotifier()),
      localeProvider.overrideWith(() => _RealLocaleNotifier()),
      authControllerProvider.overrideWith(
        () => MockAuthController(
          initialOverride: AuthAuthenticated(snap.user),
        ),
      ),
      securityStatusProvider.overrideWith(
        (ref) async => const AccountSecurityStatusResult(
          passwordConfigured: true,
          passkeyRegistered: true,
          totpEnabled: true,
          backupCodesRemaining: 8,
          unprotected: false,
          accountActivated: true,
          inboundEnabled: true,
        ),
      ),
      backupCodesStatusProvider.overrideWith(
        (ref) async => const BackupCodesStatusResult(
          enabled: true,
          remainingCodes: 8,
        ),
      ),
      balanceSettingsProvider
          .overrideWith(() => _RealBalanceSettingsNotifier()),
      biometricProvider.overrideWith(() => _RealBiometricNotifier()),
      walletProvider.overrideWith(
        () => _RealWalletNotifier(
          wallets: snap.wallets,
          btcToUsdRate: rate,
        ),
      ),
      sessionNotificationFeedProvider.overrideWith(
        () => _EmptyNotificationFeedNotifier(),
      ),
      transactionHistoryProvider.overrideWith(
        (ref) async => snap.transactions,
      ),
      lastTransactionHistoryProvider.overrideWith(
        () => _FrozenLastHistory(snap.transactions),
      ),
      depositsProvider.overrideWith((ref) async => const <Deposit>[]),
      // Freeze home HTTP surfaces (Tor would empty the UI).
      homeSurfaceProvider.overrideWith(() => _FrozenHomeSurface()),
      homeFeedProvider.overrideWith((ref) async => const <HomeFeedItem>[]),
      // Already "played" so claim() does not write during initState/build.
      homeBalanceCeremonyPlayedProvider
          .overrideWith(() => _CeremonyAlreadyPlayed()),
      // No WS / no poll timers (would fail test invariants).
      balanceWebSocketServiceProvider.overrideWith((ref) async => null),
      priceWebSocketServiceProvider
          .overrideWithValue(MockPriceWebSocketService()),
      backendBtcRatesProvider.overrideWith((ref) async => snap.rates),
      btcPriceProvider.overrideWith((ref) => Stream.value(rate)),
      btcBrlPriceProvider.overrideWithValue(brl),
      btcEurPriceProvider.overrideWithValue(eur),
      latestBtcPriceProvider.overrideWithValue(rate),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _RealWalletNotifier extends WalletNotifier {
  final List<Wallet> wallets;
  final double btcToUsdRate;

  _RealWalletNotifier({required this.wallets, required this.btcToUsdRate});

  @override
  WalletState build() => WalletLoaded(
        wallets: wallets,
        selectedWallet: wallets.isNotEmpty ? wallets.first : null,
        btcToUsdRate: btcToUsdRate,
      );

  @override
  Future<void> refresh() async {
    state = WalletLoaded(
      wallets: wallets,
      selectedWallet: wallets.isNotEmpty ? wallets.first : null,
      btcToUsdRate: btcToUsdRate,
    );
  }

  @override
  void selectWallet(Wallet wallet) {
    state = WalletLoaded(
      wallets: wallets,
      selectedWallet: wallet,
      btcToUsdRate: btcToUsdRate,
    );
  }

  @override
  Future<void> updateWalletBalance(String walletId) async {}

  @override
  void updateBalanceFromWebSocket(String walletName, double newBalance) {}
}

class _FrozenLastHistory extends LastTransactionHistoryNotifier {
  final List<Transaction> txs;
  _FrozenLastHistory(this.txs);

  @override
  List<Transaction> build() => List.unmodifiable(txs);
}

class _FrozenHomeSurface extends HomeSurfaceNotifier {
  @override
  HomeSurface build() => HomeSurface.localDefaults(locale: 'pt');

  @override
  Future<void> refresh() async {}

  @override
  void unawaitedRefresh() {}
}

class _CeremonyAlreadyPlayed extends HomeBalanceCeremonyNotifier {
  @override
  bool build() => true;
}

class _RealAppearanceNotifier extends AppearanceNotifier {
  @override
  AppearanceState build() =>
      const AppearanceState(themeVariant: AppThemeVariant.dark);
}

class _RealLocaleNotifier extends LocaleNotifier {
  @override
  LocaleState build() => LocaleState(const Locale('pt'));
}

class _RealBalanceSettingsNotifier extends BalanceSettingsNotifier {
  @override
  BalanceSettings build() =>
      const BalanceSettings(isHidden: false, decimalPlaces: 8);
}

class _EmptyNotificationFeedNotifier extends SessionNotificationFeedNotifier {
  @override
  List<SessionNotificationItem> build() => const [];
}

class _RealBiometricNotifier extends BiometricNotifier {
  @override
  BiometricState build() => const BiometricState(
        isEnabled: false,
        isSupported: false,
        isLoading: false,
      );
}
