import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import '../services/price_websocket_service.dart';

/// Provider for WebSocket price service
final priceWebSocketServiceProvider =
    Provider.autoDispose<PriceWebSocketService>((ref) {
  final service = PriceWebSocketService();
  service.connect();

  // Keep the provider alive for a brief period after the last listener is removed
  // to prevent thrashing (connecting/disposing rapidly) during transient rebuilds or navigation.
  final keepAlive = ref.keepAlive();
  Timer? timer;

  ref.onCancel(() {
    timer = Timer(const Duration(seconds: 5), () {
      keepAlive.close();
    });
  });

  ref.onResume(() {
    timer?.cancel();
  });

  // Dispose when provider is disposed
  ref.onDispose(() {
    timer?.cancel();
    service.dispose();
  });

  return service;
});

/// Stream provider for BTC price in USD
final btcPriceProvider = StreamProvider.autoDispose<double>((ref) {
  final service = ref.watch(priceWebSocketServiceProvider);
  return service.priceStream;
});

final btcTickerProvider =
    StreamProvider.autoDispose<PriceTickerSnapshot>((ref) {
  final service = ref.watch(priceWebSocketServiceProvider);
  return service.tickerStream;
});

final btcDailyChangePercentProvider = Provider.autoDispose<double?>((ref) {
  final tickerAsync = ref.watch(btcTickerProvider);
  return tickerAsync.whenOrNull(
    data: (ticker) => ticker.dailyChangePercent,
  );
});

/// Provider for latest BTC price (synchronous access).
/// Falls back to backend HTTP price when the external WebSocket feed is unavailable.
final latestBtcPriceProvider = Provider.autoDispose<double?>((ref) {
  final priceAsync = ref.watch(btcPriceProvider);
  final wsPrice = priceAsync.whenOrNull(data: (price) => price);

  if (wsPrice != null && wsPrice > 0) {
    return wsPrice;
  }

  // Fallback: use the backend's cached BTC price
  final backendRates = ref.watch(backendBtcRatesProvider);
  final backendPrice = backendRates.asData?.value?.btcUsd;
  if (backendPrice != null && backendPrice > 0) {
    return backendPrice;
  }

  return null;
});

class BackendBtcRates {
  final double btcUsd;
  final double btcBrl;
  final double btcEur;
  final double usdBrl;

  const BackendBtcRates({
    required this.btcUsd,
    required this.btcBrl,
    required this.btcEur,
    required this.usdBrl,
  });

  factory BackendBtcRates.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['rates'] is Map<String, dynamic>
            ? json['rates'] as Map<String, dynamic>
            : (json['prices'] is Map<String, dynamic>
                ? json['prices'] as Map<String, dynamic>
                : json));

    final btcUsd = _parseNum(
        root, ['btcUsd', 'btc_usd', 'BTC_USD', 'usd', 'USD', 'priceUsd']);
    final btcBrl = _parseNum(
        root, ['btcBrl', 'btc_brl', 'BTC_BRL', 'brl', 'BRL', 'priceBrl']);
    final btcEur = _parseNum(
        root, ['btcEur', 'btc_eur', 'BTC_EUR', 'eur', 'EUR', 'priceEur']);

    double usdBrl = _parseNum(root,
        ['usdBrl', 'usd_brl', 'USD_BRL', 'usd_to_brl', 'usdBrlRate', 'brlUsd']);
    if (usdBrl == 0 && btcUsd > 0 && btcBrl > 0) {
      usdBrl = btcBrl / btcUsd;
    }

    final finalBtcBrl = btcBrl > 0
        ? btcBrl
        : (btcUsd > 0 && usdBrl > 0 ? btcUsd * usdBrl : 0.0);

    return BackendBtcRates(
      btcUsd: btcUsd,
      btcBrl: finalBtcBrl,
      btcEur: btcEur,
      usdBrl: usdBrl,
    );
  }

  static double _parseNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final val = json[key];
      if (val is num && val > 0) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val.replaceAll(',', '.'));
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 0;
  }
}

final backendBtcRatesProvider =
    FutureProvider.autoDispose<BackendBtcRates?>((ref) async {
  try {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/api/economy/btc-price');
    final payload = Map<String, dynamic>.from(response.data as Map);
    return BackendBtcRates.fromJson(payload);
  } catch (_) {
    return null;
  }
});

final usdBrlRateProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(backendBtcRatesProvider).asData?.value;
  final rate = backendRates?.usdBrl;
  if (rate != null && rate > 0) return rate;
  return null;
});

/// Provider for BTC/EUR exchange rate
final btcEurPriceProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(backendBtcRatesProvider).asData?.value;
  final btcEur = backendRates?.btcEur;
  if (btcEur != null && btcEur > 0) {
    return btcEur;
  }
  return null;
});

/// Provider for BTC/BRL exchange rate
final btcBrlPriceProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(backendBtcRatesProvider).asData?.value;
  final backendBrl = backendRates?.btcBrl;
  if (backendBrl != null && backendBrl > 0) {
    return backendBrl;
  }

  final btcUsdPrice = ref.watch(latestBtcPriceProvider);
  final brlUsdRate = ref.watch(usdBrlRateProvider);
  if (btcUsdPrice == null ||
      btcUsdPrice <= 0 ||
      brlUsdRate == null ||
      brlUsdRate <= 0) {
    return null;
  }

  return btcUsdPrice * brlUsdRate;
});

/// Currency enum for multi-currency support
enum Currency {
  btc('BTC', 'Bitcoin', 8),
  usd('USD', 'US Dollar', 2),
  eur('EUR', 'Euro', 2),
  brl('BRL', 'Real', 2);

  final String code;
  final String name;
  final int decimals;

  const Currency(this.code, this.name, this.decimals);
}

final currencyQuoteProvider =
    Provider.autoDispose.family<double?, Currency>((ref, currency) {
  switch (currency) {
    case Currency.btc:
      return 1;
    case Currency.usd:
      return ref.watch(latestBtcPriceProvider);
    case Currency.eur:
      return ref.watch(btcEurPriceProvider);
    case Currency.brl:
      return ref.watch(btcBrlPriceProvider);
  }
});

/// Helper to convert any currency to BTC
double convertToBtc(
  double amount,
  Currency from,
  double? btcUsdPrice,
  double? btcEurPrice, [
  double? btcBrlPrice,
]) {
  switch (from) {
    case Currency.btc:
      return amount;
    case Currency.usd:
      if (btcUsdPrice == null || btcUsdPrice == 0) return 0;
      return amount / btcUsdPrice;
    case Currency.eur:
      if (btcEurPrice == null || btcEurPrice == 0) return 0;
      return amount / btcEurPrice;
    case Currency.brl:
      if (btcBrlPrice == null || btcBrlPrice == 0) return 0;
      return amount / btcBrlPrice;
  }
}

/// Helper to convert BTC to any currency
double convertFromBtc(
  double btcAmount,
  Currency to,
  double? btcUsdPrice,
  double? btcEurPrice, [
  double? btcBrlPrice,
]) {
  switch (to) {
    case Currency.btc:
      return btcAmount;
    case Currency.usd:
      if (btcUsdPrice == null) return 0;
      return btcAmount * btcUsdPrice;
    case Currency.eur:
      if (btcEurPrice == null) return 0;
      return btcAmount * btcEurPrice;
    case Currency.brl:
      if (btcBrlPrice == null) return 0;
      return btcAmount * btcBrlPrice;
  }
}
