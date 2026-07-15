import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kerosene/core/providers/currency_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/services/bitcoin_market_chart_service.dart';

final homeBitcoinMarketChartRangeProvider =
    StateProvider.autoDispose<BitcoinMarketChartRange>((ref) {
  return BitcoinMarketChartRange.oneDay;
});

/// Optional custom window (last N days). When non-null, overrides preset start.
final homeBitcoinMarketChartCustomDaysProvider =
    StateProvider.autoDispose<int?>((ref) => null);

final homeBitcoinMarketChartServiceProvider =
    Provider.autoDispose<BitcoinMarketChartService>((ref) {
  final service = BitcoinMarketChartService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final homeBitcoinMarketChartRequestProvider =
    Provider.autoDispose<BitcoinMarketChartRequest>((ref) {
  final selectedCurrency = ref.watch(currencyProvider);
  final quoteCurrency = _chartQuoteCurrencyFor(selectedCurrency);
  final range = ref.watch(homeBitcoinMarketChartRangeProvider);
  final customDays = ref.watch(homeBitcoinMarketChartCustomDaysProvider);

  DateTime? customStart;
  DateTime? customEnd;
  var effectiveRange = range;
  if (customDays != null && customDays > 0) {
    final now = DateTime.now();
    customEnd = now;
    customStart = now.subtract(Duration(days: customDays));
    // Map custom days to a sensible candle interval.
    effectiveRange = _rangeForCustomDays(customDays);
  }

  return BitcoinMarketChartRequest(
    symbol: _binanceSymbolFor(quoteCurrency),
    quoteCurrency: quoteCurrency,
    range: effectiveRange,
    customStart: customStart,
    customEnd: customEnd,
  );
});

final homeBitcoinMarketChartProvider =
    StreamProvider.autoDispose<BitcoinMarketChartSnapshot>((ref) {
  final request = ref.watch(homeBitcoinMarketChartRequestProvider);
  final service = ref.watch(homeBitcoinMarketChartServiceProvider);
  // Fresh fetch on range change; service keeps last series until new data arrives.
  unawaited(service.setRequest(request, forceRefresh: true));
  return service.snapshots;
});

Currency _chartQuoteCurrencyFor(Currency selectedCurrency) {
  // Chart always tracks fiat from settings; BTC display currency → default BRL.
  if (selectedCurrency == Currency.btc) {
    return Currency.brl;
  }
  return selectedCurrency;
}

String _binanceSymbolFor(Currency quoteCurrency) {
  switch (quoteCurrency) {
    case Currency.brl:
      return 'BTCBRL';
    case Currency.eur:
      return 'BTCEUR';
    case Currency.usd:
      return 'BTCUSDT';
    case Currency.btc:
      return 'BTCBRL';
  }
}

BitcoinMarketChartRange _rangeForCustomDays(int days) {
  if (days <= 3) return BitcoinMarketChartRange.threeDays;
  if (days <= 7) return BitcoinMarketChartRange.oneWeek;
  if (days <= 31) return BitcoinMarketChartRange.oneMonth;
  if (days <= 90) return BitcoinMarketChartRange.ninetyDays;
  if (days <= 366) return BitcoinMarketChartRange.oneYear;
  return BitcoinMarketChartRange.all;
}

void cycleHomeBitcoinChartRange(WidgetRef ref, {required bool forward}) {
  final values = BitcoinMarketChartRange.values;
  final current = ref.read(homeBitcoinMarketChartRangeProvider);
  // Clear custom days when cycling presets.
  ref.read(homeBitcoinMarketChartCustomDaysProvider.notifier).state = null;
  final index = values.indexOf(current);
  final next = forward
      ? values[(index + 1) % values.length]
      : values[(index - 1 + values.length) % values.length];
  ref.read(homeBitcoinMarketChartRangeProvider.notifier).state = next;
}
