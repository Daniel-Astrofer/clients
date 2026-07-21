import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/localization/app_localization_manager.dart';
import 'package:kerosene/core/localization/app_timezone.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';

import 'price_provider.dart';
import 'shared_preferences_provider.dart';

class AppDisplayPreferencesState {
  final Locale locale;
  final Currency currency;

  /// IANA or UTC±HH:MM id used for API content personalization and local clocks.
  final String timeZoneId;

  /// When true, timezone tracks the device automatically.
  final bool timeZoneFollowDevice;

  const AppDisplayPreferencesState({
    required this.locale,
    required this.currency,
    required this.timeZoneId,
    required this.timeZoneFollowDevice,
  });

  AppDisplayPreferencesState copyWith({
    Locale? locale,
    Currency? currency,
    String? timeZoneId,
    bool? timeZoneFollowDevice,
  }) {
    return AppDisplayPreferencesState(
      locale: locale ?? this.locale,
      currency: currency ?? this.currency,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      timeZoneFollowDevice: timeZoneFollowDevice ?? this.timeZoneFollowDevice,
    );
  }
}

class AppDisplayPreferencesNotifier
    extends Notifier<AppDisplayPreferencesState> {
  static const String _localeKey = 'app_locale';
  static const String _currencyKey = 'app_currency';
  static const String _timeZoneKey = 'app_timezone';
  static const String _timeZoneFollowKey = 'app_timezone_follow_device';

  /// Secure mirror keys (survive SharedPreferences clears on some Android OEMs).
  static const String _secureLocaleKey = 'secure_app_locale';
  static const String _secureCurrencyKey = 'secure_app_currency';
  static const String _secureTimeZoneKey = 'secure_app_timezone';

  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  AppDisplayPreferencesState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final locale = AppLocalizationManager.resolve(
      Locale(
        prefs.getString(_localeKey) ??
            AppLocalizationManager.deviceOrFallback().languageCode,
      ),
    );
    final currency = _parseCurrency(prefs.getString(_currencyKey));
    final followDevice = prefs.getBool(_timeZoneFollowKey) ?? true;
    final storedTz = prefs.getString(_timeZoneKey);
    final timeZoneId =
        followDevice ? AppTimezone.detectId() : AppTimezone.resolve(storedTz);

    // Best-effort secure mirror restore is async — kick off without blocking build.
    Future.microtask(_hydrateFromSecureMirror);

    return AppDisplayPreferencesState(
      locale: locale,
      currency: currency,
      timeZoneId: timeZoneId,
      timeZoneFollowDevice: followDevice,
    );
  }

  Future<void> _hydrateFromSecureMirror() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      var changed = false;

      if (prefs.getString(_localeKey) == null) {
        final secureLocale = await _secureStorage.read(key: _secureLocaleKey);
        if (secureLocale != null && secureLocale.isNotEmpty) {
          await prefs.setString(_localeKey, secureLocale);
          changed = true;
        }
      }
      if (prefs.getString(_currencyKey) == null) {
        final secureCurrency =
            await _secureStorage.read(key: _secureCurrencyKey);
        if (secureCurrency != null && secureCurrency.isNotEmpty) {
          await prefs.setString(_currencyKey, secureCurrency);
          changed = true;
        }
      }
      if (prefs.getString(_timeZoneKey) == null) {
        final secureTz = await _secureStorage.read(key: _secureTimeZoneKey);
        if (secureTz != null && secureTz.isNotEmpty) {
          await prefs.setString(_timeZoneKey, secureTz);
          changed = true;
        }
      }

      if (changed && ref.mounted) {
        // Rebuild from prefs after secure restore.
        final nextLocale = AppLocalizationManager.resolve(
          Locale(
            prefs.getString(_localeKey) ??
                AppLocalizationManager.deviceOrFallback().languageCode,
          ),
        );
        final nextCurrency = _parseCurrency(prefs.getString(_currencyKey));
        final follow = prefs.getBool(_timeZoneFollowKey) ?? true;
        final tz = follow
            ? AppTimezone.detectId()
            : AppTimezone.resolve(prefs.getString(_timeZoneKey));
        state = AppDisplayPreferencesState(
          locale: nextLocale,
          currency: nextCurrency,
          timeZoneId: tz,
          timeZoneFollowDevice: follow,
        );
      }
    } catch (_) {
      // Non-fatal: prefs alone are enough for UI.
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = AppLocalizationManager.resolve(locale);
    state = state.copyWith(locale: next);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_localeKey, next.languageCode);
    await _mirrorSecure(_secureLocaleKey, next.languageCode);
  }

  Future<void> setCurrency(Currency currency) async {
    state = state.copyWith(currency: currency);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_currencyKey, currency.code);
    await _mirrorSecure(_secureCurrencyKey, currency.code);
  }

  Future<void> setTimeZoneFollowDevice(bool follow) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_timeZoneFollowKey, follow);
    if (follow) {
      final detected = AppTimezone.detectId();
      state = state.copyWith(
        timeZoneFollowDevice: true,
        timeZoneId: detected,
      );
      await prefs.setString(_timeZoneKey, detected);
      await _mirrorSecure(_secureTimeZoneKey, detected);
    } else {
      state = state.copyWith(timeZoneFollowDevice: false);
    }
  }

  Future<void> setTimeZoneId(String timeZoneId) async {
    final resolved = AppTimezone.resolve(timeZoneId);
    state = state.copyWith(
      timeZoneId: resolved,
      timeZoneFollowDevice: false,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_timeZoneFollowKey, false);
    await prefs.setString(_timeZoneKey, resolved);
    await _mirrorSecure(_secureTimeZoneKey, resolved);
  }

  /// Refresh device timezone when the OS offset changes (travel / DST).
  Future<void> refreshDeviceTimeZoneIfFollowing() async {
    if (!state.timeZoneFollowDevice) return;
    final detected = AppTimezone.detectId();
    if (detected == state.timeZoneId) return;
    state = state.copyWith(timeZoneId: detected);
    await ref.read(sharedPreferencesProvider).setString(_timeZoneKey, detected);
    await _mirrorSecure(_secureTimeZoneKey, detected);
  }

  Future<void> toggleCurrency() async {
    switch (state.currency) {
      case Currency.usd:
        await setCurrency(Currency.brl);
        break;
      case Currency.brl:
        await setCurrency(Currency.eur);
        break;
      case Currency.eur:
        await setCurrency(Currency.btc);
        break;
      case Currency.btc:
        await setCurrency(Currency.usd);
        break;
    }
  }

  Future<void> _mirrorSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  Currency _parseCurrency(String? code) {
    final normalized = code?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      // Currency default follows language when first install.
      final lang = AppLocalizationManager.deviceOrFallback().languageCode;
      return switch (lang) {
        'pt' => Currency.brl,
        'es' => Currency.eur,
        _ => Currency.usd,
      };
    }
    return Currency.values.firstWhere(
      (currency) => currency.code == normalized,
      orElse: () => Currency.brl,
    );
  }
}

final appDisplayPreferencesProvider =
    NotifierProvider<AppDisplayPreferencesNotifier, AppDisplayPreferencesState>(
  AppDisplayPreferencesNotifier.new,
);
