import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/price_provider.dart';

void main() {
  group('BackendBtcRates.fromJson', () {
    test('parses standard camelCase JSON keys', () {
      final rates = BackendBtcRates.fromJson({
        'btcUsd': 65000.0,
        'btcBrl': 357500.0,
        'btcEur': 60000.0,
        'usdBrl': 5.5,
      });

      expect(rates.btcUsd, 65000.0);
      expect(rates.btcBrl, 357500.0);
      expect(rates.btcEur, 60000.0);
      expect(rates.usdBrl, 5.5);
    });

    test('parses snake_case and alternative JSON keys', () {
      final rates = BackendBtcRates.fromJson({
        'btc_usd': '65000.0',
        'btc_brl': '357500.0',
        'btc_eur': '60000.0',
        'usd_brl': '5.5',
      });

      expect(rates.btcUsd, 65000.0);
      expect(rates.btcBrl, 357500.0);
      expect(rates.btcEur, 60000.0);
      expect(rates.usdBrl, 5.5);
    });

    test('derives usdBrl when only btcBrl and btcUsd are provided', () {
      final rates = BackendBtcRates.fromJson({
        'btcUsd': 60000.0,
        'btcBrl': 330000.0,
      });

      expect(rates.usdBrl, 5.5);
      expect(rates.btcBrl, 330000.0);
    });

    test('derives btcBrl when only usdBrl and btcUsd are provided', () {
      final rates = BackendBtcRates.fromJson({
        'btcUsd': 60000.0,
        'usdBrl': 5.6,
      });

      expect(rates.btcBrl, 336000.0);
    });

    test('parses rates nested under data or rates map', () {
      final rates = BackendBtcRates.fromJson({
        'rates': {
          'USD': 62000.0,
          'BRL': 341000.0,
        }
      });

      expect(rates.btcUsd, 62000.0);
      expect(rates.btcBrl, 341000.0);
      expect(rates.usdBrl, 5.5);
    });
  });

  group('btcBrlPriceProvider strict behavior', () {
    test('returns null when no real backend rates are available', () {
      final container = ProviderContainer(
        overrides: [
          latestBtcPriceProvider.overrideWith((ref) => 60000.0),
          backendBtcRatesProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final brlPrice = container.read(btcBrlPriceProvider);
      expect(brlPrice, isNull);
    });

    test('calculates BRL price when real usdBrl rate is provided by backend', () {
      final container = ProviderContainer(
        overrides: [
          latestBtcPriceProvider.overrideWith((ref) => 60000.0),
          backendBtcRatesProvider.overrideWith(
            (ref) => BackendBtcRates.fromJson({'usdBrl': 5.6}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final brlPrice = container.read(btcBrlPriceProvider);
      expect(brlPrice, 60000.0 * 5.6);
    });
  });
}
