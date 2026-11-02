import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';

void main() {
  test('operation precision is complete regardless of balance preferences', () {
    const money = MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2);
    expect(money.primary(0.12345678), '0,12345678 BTC');
    expect(money.secondary(0.12345678), isEmpty);
    expect(money.primary(0.12), '0,12000000 BTC');
    expect(money.secondary(0.12), isEmpty);
  });
  test('small positive and negative values never become zero', () {
    const money = MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2);
    expect(money.primary(0.00000001), '0,00000001 BTC');
    expect(money.secondary(0.00000001), isEmpty);
    expect(money.primary(-0.00000001), '-0,00000001 BTC');
    expect(money.secondary(-0.00000001), isEmpty);
    expect(money.primary(0), '0,00000000 BTC');
  });
  test('journal preserves unit locale precision and captured quote', () {
    const original = MovementMoney(
        currency: Currency.brl,
        locale: Locale('pt', 'BR'),
        btcDecimalPlaces: 4,
        btcBrl: 500000);
    final restored = MovementMoney.fromJournal(original.toJournal());
    expect(restored.currency, Currency.brl);
    expect(restored.locale, const Locale('pt', 'BR'));
    expect(restored.btcDecimalPlaces, 4);
    expect(restored.primary(0.001), '0,00100000 BTC');
    expect(restored.secondary(0.001), isEmpty);
  });
  test('legacy and invalid precision keep full precision', () {
    for (final value in [null, -1, 3, 99, '2']) {
      final restored = MovementMoney.fromJournal({'btcDecimalPlaces': value});
      expect(restored.btcDecimalPlaces, 8);
      expect(restored.primary(0.12345678), '0,12345678 BTC');
    }
  });
  test('unavailable quote falls back to known BTC without inventing fiat', () {
    const money = MovementMoney(
        currency: Currency.usd, locale: Locale('en'), btcDecimalPlaces: 4);
    expect(money.primary(0.12345678), '0.12345678 BTC');
    expect(money.secondary(0.12345678), isEmpty);
  });
  test('nonfinite values are unavailable instead of NaN amounts', () {
    const money = MovementMoney();
    for (final value in [double.nan, double.infinity]) {
      expect(money.primary(value), '— BTC');
      expect(money.secondary(value), isEmpty);
    }
  });
}
