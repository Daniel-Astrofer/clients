import 'package:flutter/widgets.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';

/// Display context captured when entering a financial journey. A preference or
/// market refresh must not silently change its unit or quote during review.
class MovementMoney {
  final Currency currency;
  final Locale? locale;
  final int btcDecimalPlaces;
  final double? btcUsd;
  final double? btcEur;
  final double? btcBrl;

  const MovementMoney({
    this.currency = Currency.btc,
    this.locale,
    this.btcDecimalPlaces = 8,
    this.btcUsd,
    this.btcEur,
    this.btcBrl,
  });

  Map<String, Object?> toJournal() => {
        'currency': currency.code,
        'btcDecimalPlaces': _displayDecimals,
        if (locale != null) 'locale': locale!.toLanguageTag(),
        if (btcUsd != null && btcUsd!.isFinite && btcUsd! > 0) 'btcUsd': btcUsd,
        if (btcEur != null && btcEur!.isFinite && btcEur! > 0) 'btcEur': btcEur,
        if (btcBrl != null && btcBrl!.isFinite && btcBrl! > 0) 'btcBrl': btcBrl,
      };

  factory MovementMoney.fromJournal(Map<String, Object?> data) {
    final parts = (data['locale'] as String? ?? 'pt').split('-');
    return MovementMoney(
        currency: Currency.values.firstWhere(
            (value) => value.code == data['currency'],
            orElse: () => Currency.btc),
        locale: Locale(parts.first, parts.length > 1 ? parts[1] : null),
        btcDecimalPlaces: switch (data['btcDecimalPlaces']) {
          2 => 2,
          4 => 4,
          _ => 8
        },
        btcUsd: (data['btcUsd'] as num?)?.toDouble(),
        btcEur: (data['btcEur'] as num?)?.toDouble(),
        btcBrl: (data['btcBrl'] as num?)?.toDouble());
  }

  double? get rate => switch (currency) {
        Currency.btc => 1,
        Currency.usd => btcUsd,
        Currency.eur => btcEur,
        Currency.brl => btcBrl,
      };

  /// Journey values are BTC operations; a market quote is not a fiat record.
  String primary(double btc) => asset(btc);

  int get _displayDecimals =>
      switch (btcDecimalPlaces) { 2 => 2, 4 => 4, _ => 8 };

  String asset(double btc) => !btc.isFinite
      ? '— BTC'
      : MoneyDisplay.formatOperationAmount(
          satoshis: (btc * 100000000).round(), appLocale: locale);

  String primarySatoshis(int sats) =>
      MoneyDisplay.formatOperationAmount(satoshis: sats, appLocale: locale);

  String secondary(double btc) => '';
}
