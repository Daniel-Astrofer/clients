import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';

/// Snapshot of global money presentation prefs (currency + app locale).
///
/// Watch this so labels reformat when the user changes language or currency.
@immutable
class MoneyFormatConfig {
  final Currency currency;
  final Locale locale;

  const MoneyFormatConfig({
    required this.currency,
    required this.locale,
  });

  String get numberLocaleTag => MoneyDisplay.numberLocaleTag(locale);

  String format({
    required double amount,
    Currency? currency,
    bool withSymbol = true,
    int? decimalPlaces,
  }) {
    return MoneyDisplay.format(
      amount: amount,
      currency: currency ?? this.currency,
      withSymbol: withSymbol,
      decimalPlaces: decimalPlaces,
      appLocale: locale,
    );
  }

  String formatCompact({
    required double amount,
    Currency? currency,
    bool withSymbol = true,
    int? maxDecimalPlaces,
  }) {
    return MoneyDisplay.formatCompact(
      amount: amount,
      currency: currency ?? this.currency,
      withSymbol: withSymbol,
      maxDecimalPlaces: maxDecimalPlaces,
      appLocale: locale,
    );
  }

  String formatAmountFromBtc({
    required double btcAmount,
    Currency? currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    bool withSymbol = true,
    bool signed = false,
    int? decimalPlaces,
  }) {
    return MoneyDisplay.formatAmountFromBtc(
      btcAmount: btcAmount,
      currency: currency ?? this.currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      withSymbol: withSymbol,
      signed: signed,
      decimalPlaces: decimalPlaces,
      appLocale: locale,
    );
  }

  String formatFrozenAmountFromBtc({
    required double btcAmount,
    Currency? currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    double? displayAmountUsd,
    double? displayAmountEur,
    double? displayAmountBrl,
    double? displayBtcUsd,
    double? displayBtcEur,
    double? displayBtcBrl,
    bool withSymbol = true,
    bool signed = false,
  }) {
    return MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: btcAmount,
      currency: currency ?? this.currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: displayAmountUsd,
      displayAmountEur: displayAmountEur,
      displayAmountBrl: displayAmountBrl,
      displayBtcUsd: displayBtcUsd,
      displayBtcEur: displayBtcEur,
      displayBtcBrl: displayBtcBrl,
      withSymbol: withSymbol,
      signed: signed,
      appLocale: locale,
    );
  }
}

/// Reactive money formatting bound to [appDisplayPreferencesProvider].
final moneyFormatConfigProvider = Provider<MoneyFormatConfig>((ref) {
  final prefs = ref.watch(appDisplayPreferencesProvider);
  return MoneyFormatConfig(
    currency: prefs.currency,
    locale: prefs.locale,
  );
});
