import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';

void main() {
  test('pasted grouped amounts preserve the amount in both decimal conventions',
      () {
    for (final input in ['R\$ 1.234,56', 'US\$ 1,234.56']) {
      expect(
          MoneyDisplay.sanitizeEditableInput(
              rawValue: input, currency: Currency.brl),
          '1234.56');
    }
    expect(
        MoneyDisplay.sanitizeEditableInput(
            rawValue: '1.234,56789012 BTC', currency: Currency.btc),
        '1234.56789012');
    expect(
        MoneyDisplay.sanitizeEditableInput(
            rawValue: '0,12345678', currency: Currency.btc),
        '0.12345678');
  });
  test('negative pasted amounts never silently turn into positive payments',
      () {
    for (final input in [
      '-123,45',
      '−123,45',
      '(1.234,56)',
      'R\$ -123,45',
      'US\$ −1,234.56'
    ]) {
      expect(
          MoneyDisplay.sanitizeEditableInput(
              rawValue: input, currency: Currency.brl),
          '0');
    }
  });
  group('MoneyDisplay editable input helpers', () {
    test('shows only zero by default', () {
      expect(
        MoneyDisplay.formatEditableInput(
          rawValue: '0',
          currency: Currency.btc,
          withSymbol: false,
        ),
        '0',
      );
    });

    test('preserves only typed decimal places for btc', () {
      expect(
        MoneyDisplay.formatEditableInput(
          rawValue: '12.34',
          currency: Currency.btc,
          withSymbol: false,
        ),
        '12.34',
      );
    });

    test('uses locale separator for fiat input display', () {
      expect(
        MoneyDisplay.formatEditableInput(
          rawValue: '1234.5',
          currency: Currency.brl,
          withSymbol: false,
        ),
        '1.234,5',
      );
    });

    test('keeps trailing decimal separator while typing', () {
      expect(
        MoneyDisplay.formatEditableInput(
          rawValue: '0.',
          currency: Currency.usd,
          withSymbol: false,
        ),
        '0.',
      );
    });

    test('keypad input limits btc decimals and preserves zero state', () {
      var value = '0';
      value = MoneyDisplay.applyKeypadInput(
        currentValue: value,
        key: '.',
        currency: Currency.btc,
      );
      value = MoneyDisplay.applyKeypadInput(
        currentValue: value,
        key: '1',
        currency: Currency.btc,
      );

      for (final digit in ['2', '3', '4', '5', '6', '7', '8', '9']) {
        value = MoneyDisplay.applyKeypadInput(
          currentValue: value,
          key: digit,
          currency: Currency.btc,
        );
      }

      expect(value, '0.12345678');

      final unchanged = MoneyDisplay.applyKeypadInput(
        currentValue: value,
        key: '9',
        currency: Currency.btc,
      );
      expect(unchanged, '0.12345678');

      expect(
        MoneyDisplay.applyKeypadInput(
          currentValue: '0',
          key: '0',
          currency: Currency.btc,
        ),
        '0',
      );
    });
  });
  test('history without a fiat quote shows known BTC rather than fiat zero',
      () {
    for (final currency in [Currency.usd, Currency.eur, Currency.brl]) {
      final value = MoneyDisplay.formatFrozenAmountFromBtc(
          btcAmount: -0.1,
          currency: currency,
          btcUsd: null,
          btcEur: null,
          btcBrl: null,
          signed: true);
      expect(value, contains('BTC'));
      expect(value, startsWith('-'));
      expect(value, isNot(contains('0.00')));
    }
  });
  test('quotes never replace a missing recorded fiat amount', () {
    final value = MoneyDisplay.formatFrozenAmountFromBtc(
        btcAmount: 0.1,
        currency: Currency.usd,
        btcUsd: 100,
        btcEur: null,
        btcBrl: null,
        displayAmountUsd: double.nan,
        displayBtcUsd: double.infinity);
    expect(value, '0.10000000 BTC');
  });
  test('negative tiny operation shows every satoshi', () {
    final value = MoneyDisplay.formatFrozenAmountFromBtc(
        btcAmount: -0.00000001,
        currency: Currency.btc,
        btcUsd: null,
        btcEur: null,
        btcBrl: null,
        signed: true,
        decimalPlaces: 2);
    expect(value, equals('-0.00000001 BTC'));
    expect(value, isNot(startsWith('-<')));
  });
  test(
      'operation amounts preserve integer satoshis even above double precision',
      () {
    expect(MoneyDisplay.formatOperationAmount(satoshis: 9007199254740993),
        '90071992.54740993 BTC');
    expect(MoneyDisplay.formatOperationAmount(satoshis: -1, signed: true),
        '-0.00000001 BTC');
    expect(MoneyDisplay.formatOperationAmount(satoshis: 0, signed: true),
        '+0.00000000 BTC');
  });
  test('operation formatting retains the explicit no-symbol contract', () {
    expect(MoneyDisplay.formatOperationAmount(satoshis: 1, withSymbol: false),
        '0.00000001');
    expect(
        MoneyDisplay.formatOperationAmount(
            satoshis: -100,
            currency: Currency.usd,
            recordedFiat: 10,
            signed: true,
            withSymbol: false),
        '-10.00');
  });
  test('recorded fiat preserves sub-cent data without fabricated rounding', () {
    expect(
        MoneyDisplay.formatOperationAmount(
            satoshis: 1, currency: Currency.usd, recordedFiat: 0.001),
        contains('0.001'));
    expect(
        MoneyDisplay.formatOperationAmount(
            satoshis: 1, currency: Currency.usd, recordedFiat: double.nan),
        '0.00000001 BTC');
  });
  test('nonzero fiat values smaller than one cent never appear as zero', () {
    for (final currency in [Currency.usd, Currency.eur, Currency.brl]) {
      expect(MoneyDisplay.format(amount: 0.001, currency: currency),
          startsWith('<'));
      expect(MoneyDisplay.format(amount: -0.001, currency: currency),
          startsWith('> -'));
    }
  });
}
