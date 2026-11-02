import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';

void main() {
  test('money formatting follows scoped precision without changing fiat',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_locale': 'pt',
      'app_currency': 'USD',
      'balance_decimals_alice': 4,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionStorageScopeProvider.overrideWithValue('alice'),
    ]);
    addTearDown(container.dispose);
    container.read(moneyFormatConfigProvider);
    await Future<void>.delayed(Duration.zero);
    final captured = container.read(moneyFormatConfigProvider);
    expect(captured.currency, Currency.usd);
    expect(captured.btcDecimalPlaces, 4);
    expect(captured.format(amount: 0.12345678, currency: Currency.btc),
        '₿ 0,1235');
    container.read(balanceSettingsProvider.notifier).setDecimalPlaces(2);
    final updated = container.read(moneyFormatConfigProvider);
    expect(updated.currency, Currency.usd);
    expect(updated.btcDecimalPlaces, 2);
    expect(updated.format(amount: 12.3456), 'US\$ 12,35');
    expect(captured.btcDecimalPlaces, 4);
  });
  test('balance precision stays separate from exact recorded operations', () {
    const money = MoneyFormatConfig(
        currency: Currency.btc, locale: Locale('pt'), btcDecimalPlaces: 2);
    expect(money.format(amount: 0.00000001), '₿ < 0,01');
    expect(money.formatCompact(amount: 0.00000001), '₿ < 0,01');
    expect(
        money.formatAmountFromBtc(
            btcAmount: 0.00000001, btcUsd: null, btcEur: null, btcBrl: null),
        '₿ < 0,01');
    expect(
        money.formatFrozenAmountFromBtc(
            btcAmount: 0.00000001, btcUsd: null, btcEur: null, btcBrl: null),
        '0,00000001 BTC');
    expect(money.format(amount: 0.00000001, decimalPlaces: 8), '₿ 0,00000001');
  });
}
