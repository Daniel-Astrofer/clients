import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

class AlertPreferencesState {
  final bool backgroundAlertsEnabled;
  final bool inAppBannersEnabled;
  final bool transactionAlertsEnabled;
  final bool securityAlertsEnabled;
  final bool marketAlertsEnabled;

  const AlertPreferencesState({
    // Default ON so cold/on-chain alerts work after install without digging settings.
    this.backgroundAlertsEnabled = true,
    this.inAppBannersEnabled = true,
    this.transactionAlertsEnabled = true,
    this.securityAlertsEnabled = true,
    this.marketAlertsEnabled = false,
  });

  AlertPreferencesState copyWith({
    bool? backgroundAlertsEnabled,
    bool? inAppBannersEnabled,
    bool? transactionAlertsEnabled,
    bool? securityAlertsEnabled,
    bool? marketAlertsEnabled,
  }) {
    return AlertPreferencesState(
      backgroundAlertsEnabled:
          backgroundAlertsEnabled ?? this.backgroundAlertsEnabled,
      inAppBannersEnabled: inAppBannersEnabled ?? this.inAppBannersEnabled,
      transactionAlertsEnabled:
          transactionAlertsEnabled ?? this.transactionAlertsEnabled,
      securityAlertsEnabled:
          securityAlertsEnabled ?? this.securityAlertsEnabled,
      marketAlertsEnabled: marketAlertsEnabled ?? this.marketAlertsEnabled,
    );
  }
}

class AlertPreferencesNotifier extends Notifier<AlertPreferencesState> {
  static const String backgroundAlertsKey = 'background_alerts_enabled';
  static const String inAppBannersKey = 'in_app_banners_enabled';
  static const String transactionAlertsKey = 'transaction_alerts_enabled';
  static const String securityAlertsKey = 'security_alerts_enabled';
  static const String marketAlertsKey = 'market_alerts_enabled';

  @override
  AlertPreferencesState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AlertPreferencesState(
      backgroundAlertsEnabled: prefs.getBool(backgroundAlertsKey) ?? true,
      inAppBannersEnabled: prefs.getBool(inAppBannersKey) ?? true,
      transactionAlertsEnabled: prefs.getBool(transactionAlertsKey) ?? true,
      securityAlertsEnabled: prefs.getBool(securityAlertsKey) ?? true,
      marketAlertsEnabled: prefs.getBool(marketAlertsKey) ?? false,
    );
  }

  Future<void> setBackgroundAlertsEnabled(bool enabled) async {
    await _save(backgroundAlertsKey, enabled);
    state = state.copyWith(backgroundAlertsEnabled: enabled);
  }

  Future<void> setInAppBannersEnabled(bool enabled) async {
    await _save(inAppBannersKey, enabled);
    state = state.copyWith(inAppBannersEnabled: enabled);
  }

  Future<void> setTransactionAlertsEnabled(bool enabled) async {
    await _save(transactionAlertsKey, enabled);
    state = state.copyWith(transactionAlertsEnabled: enabled);
  }

  Future<void> setSecurityAlertsEnabled(bool enabled) async {
    await _save(securityAlertsKey, enabled);
    state = state.copyWith(securityAlertsEnabled: enabled);
  }

  Future<void> setMarketAlertsEnabled(bool enabled) async {
    await _save(marketAlertsKey, enabled);
    state = state.copyWith(marketAlertsEnabled: enabled);
  }

  Future<void> _save(String key, bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      if (!await prefs.setBool(key, enabled)) {
        throw StateError('Alert preference was not saved.');
      }
    } catch (_) {
      // Legacy SharedPreferences changes its cache before the platform commit.
      await prefs.reload();
      rethrow;
    }
  }
}

Future<bool> loadBackgroundAlertsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(AlertPreferencesNotifier.backgroundAlertsKey) ?? true;
}

final alertPreferencesProvider =
    NotifierProvider<AlertPreferencesNotifier, AlertPreferencesState>(
  AlertPreferencesNotifier.new,
);
