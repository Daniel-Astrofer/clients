import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kerosene/app/debug/device_ui_snapshot.dart';
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
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/presentation/providers/home_feed_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/movement/data/entities/deposit.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';

/// Builds a **frozen** Riverpod tree from a device snapshot so gallery renders
/// show real wallets/txs/user **without** hitting the network (Tor).
Widget buildFrozenGalleryApp({
  required DeviceUiSnapshot snapshot,
  required SharedPreferences prefs,
  required Widget home,
  double width = 390,
  double height = 3000,
}) {
  final rate = snapshot.rates.btcUsd > 0 ? snapshot.rates.btcUsd : 67234.5;
  final brl = snapshot.rates.btcBrl > 0 ? snapshot.rates.btcBrl : rate * 5;
  final eur = snapshot.rates.btcEur > 0 ? snapshot.rates.btcEur : rate * 0.92;

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
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
      appearanceProvider.overrideWith(() => _GalleryAppearance()),
      localeProvider.overrideWith(() => _GalleryLocale()),
      authControllerProvider.overrideWith(
        () => MockAuthController(
          initialOverride: AuthAuthenticated(snapshot.user),
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
      balanceSettingsProvider.overrideWith(() => _GalleryBalance()),
      biometricProvider.overrideWith(() => _GalleryBiometric()),
      // ★ Frozen financial data from the live device session
      walletProvider.overrideWith(
        () => _FrozenWalletNotifier(
          wallets: snapshot.wallets,
          btcToUsdRate: rate,
        ),
      ),
      transactionHistoryProvider.overrideWith(
        (ref) async => snapshot.transactions,
      ),
      lastTransactionHistoryProvider.overrideWith(
        () => _FrozenLastHistory(snapshot.transactions),
      ),
      depositsProvider.overrideWith((ref) async => const <Deposit>[]),
      // ★ Freeze home content — no HTTP during off-screen render
      homeSurfaceProvider.overrideWith(() => _FrozenHomeSurface()),
      homeFeedProvider.overrideWith(
        (ref) async => const <HomeFeedItem>[],
      ),
      sessionNotificationFeedProvider.overrideWith(
        () => _EmptyNotifs(),
      ),
      priceWebSocketServiceProvider
          .overrideWithValue(MockPriceWebSocketService()),
      backendBtcRatesProvider.overrideWith((ref) async => snapshot.rates),
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
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          devicePixelRatio: 2.0,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        ),
        child: home,
      ),
    ),
  );
}

class _FrozenWalletNotifier extends WalletNotifier {
  final List<Wallet> wallets;
  final double btcToUsdRate;

  _FrozenWalletNotifier({
    required this.wallets,
    required this.btcToUsdRate,
  });

  @override
  WalletState build() {
    return WalletLoaded(
      wallets: wallets,
      selectedWallet: wallets.isNotEmpty ? wallets.first : null,
      btcToUsdRate: btcToUsdRate,
    );
  }

  @override
  Future<void> refresh() async {
    // Freeze — do not hit network (would empty UI on Tor failure).
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
  HomeSurface build() {
    // No network listeners / no refresh kickoff.
    return HomeSurface.localDefaults(locale: 'pt');
  }

  @override
  Future<void> refresh() async {}

  @override
  void unawaitedRefresh() {}
}

class _GalleryAppearance extends AppearanceNotifier {
  @override
  AppearanceState build() =>
      const AppearanceState(themeVariant: AppThemeVariant.dark);
}

class _GalleryLocale extends LocaleNotifier {
  @override
  LocaleState build() => LocaleState(const Locale('pt'));
}

class _GalleryBalance extends BalanceSettingsNotifier {
  @override
  BalanceSettings build() =>
      const BalanceSettings(isHidden: false, decimalPlaces: 8);
}

class _GalleryBiometric extends BiometricNotifier {
  @override
  BiometricState build() => const BiometricState(
        isEnabled: false,
        isSupported: false,
        isLoading: false,
      );
}

class _EmptyNotifs extends SessionNotificationFeedNotifier {
  @override
  List<SessionNotificationItem> build() => const [];
}
