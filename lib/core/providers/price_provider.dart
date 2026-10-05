import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import '../services/price_websocket_service.dart';

/// Clearnet exchange feed (Binance/Coinbase) — optional live USD overlay / alerts.
///
/// Display quotes for balances prefer [backendBtcRatesProvider] (sovereign
/// Kerosene API). This external socket is not required for BRL/EUR on home.
final priceWebSocketServiceProvider =
    Provider.autoDispose<PriceWebSocketService>((ref) {
  final service = PriceWebSocketService();
  service.connect();

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

  ref.onDispose(() {
    timer?.cancel();
    service.dispose();
  });

  return service;
});

/// Stream provider for BTC price in USD (external clearnet feed).
final btcPriceProvider = StreamProvider.autoDispose<double>((ref) {
  final service = ref.watch(priceWebSocketServiceProvider);
  return service.priceStream;
});

final btcTickerProvider =
    StreamProvider.autoDispose<PriceTickerSnapshot>((ref) {
  final service = ref.watch(priceWebSocketServiceProvider);
  return service.tickerStream;
});

/// 24h change: live WS / backend first, then external ticker if present.
final btcDailyChangePercentProvider = Provider.autoDispose<double?>((ref) {
  final live = ref.watch(liveBackendBtcRatesProvider);
  final fromLive = live?.btcUsdChange24hPercent;
  if (fromLive != null) {
    return fromLive;
  }

  final backend = ref.watch(backendBtcRatesProvider).asData?.value;
  final fromBackend = backend?.btcUsdChange24hPercent;
  if (fromBackend != null) {
    return fromBackend;
  }

  final tickerAsync = ref.watch(btcTickerProvider);
  return tickerAsync.whenOrNull(
    data: (ticker) => ticker.dailyChangePercent,
  );
});

/// Latest BTC/USD for display — live STOMP / HTTP backend first.
///
/// External Binance/Coinbase is a last-resort overlay only.
final latestBtcPriceProvider = Provider.autoDispose<double?>((ref) {
  final resolved = ref.watch(resolvedBackendBtcRatesProvider);
  final backendPrice = resolved?.btcUsd;
  if (backendPrice != null && backendPrice > 0) {
    return backendPrice;
  }

  final priceAsync = ref.watch(btcPriceProvider);
  final wsPrice = priceAsync.whenOrNull(data: (price) => price);
  if (wsPrice != null && wsPrice > 0) {
    return wsPrice;
  }

  return null;
});

class BackendBtcRates {
  final double btcUsd;
  final double btcBrl;
  final double btcEur;
  final double usdBrl;
  final double? btcUsdChange24hPercent;

  const BackendBtcRates({
    required this.btcUsd,
    required this.btcBrl,
    required this.btcEur,
    required this.usdBrl,
    this.btcUsdChange24hPercent,
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

    final change = _parseSignedNum(root, [
      'btcUsdChange24hPercent',
      'btc_usd_change_24h_percent',
      'change24h',
      'usd_24h_change',
    ]);

    return BackendBtcRates(
      btcUsd: btcUsd,
      btcBrl: finalBtcBrl,
      btcEur: btcEur,
      usdBrl: usdBrl,
      btcUsdChange24hPercent: change,
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

  static double? _parseSignedNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final val = json[key];
      if (val is num) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

/// Live rates from STOMP `/topic/btc-price` (updated each CoinGecko poll).
final liveBackendBtcRatesProvider =
    NotifierProvider<LiveBackendBtcRatesNotifier, BackendBtcRates?>(
  LiveBackendBtcRatesNotifier.new,
);

class LiveBackendBtcRatesNotifier extends Notifier<BackendBtcRates?> {
  @override
  BackendBtcRates? build() => null;

  void apply(BackendBtcRates rates) {
    if (rates.btcUsd <= 0 && rates.btcBrl <= 0) return;
    state = rates;
  }

  void clear() => state = null;
}

/// Prefer STOMP live rates; fall back to HTTP bootstrap.
final resolvedBackendBtcRatesProvider = Provider.autoDispose<BackendBtcRates?>((
  ref,
) {
  final live = ref.watch(liveBackendBtcRatesProvider);
  if (live != null && (live.btcUsd > 0 || live.btcBrl > 0)) {
    return live;
  }
  return ref.watch(backendBtcRatesProvider).asData?.value;
});

/// Sovereign BTC quotes from Kerosene HTTP (`GET /api/economy/btc-price`).
///
/// Bootstrap / fallback when STOMP `/topic/btc-price` has not delivered yet.
/// Refresh is slower when live WS rates are already present.
final backendBtcRatesProvider =
    FutureProvider.autoDispose<BackendBtcRates?>((ref) async {
  final hasLive = ref.read(liveBackendBtcRatesProvider) != null;
  final refresh = Timer(
    Duration(minutes: hasLive ? 5 : 2),
    () {
      ref.invalidateSelf();
    },
  );
  ref.onDispose(refresh.cancel);

  try {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/api/economy/btc-price');
    final payload = Map<String, dynamic>.from(response.data as Map);
    final rates = BackendBtcRates.fromJson(payload);
    // Seed live cache if STOMP has not spoken yet.
    if (ref.read(liveBackendBtcRatesProvider) == null &&
        (rates.btcUsd > 0 || rates.btcBrl > 0)) {
      ref.read(liveBackendBtcRatesProvider.notifier).apply(rates);
    }
    return rates;
  } catch (_) {
    return null;
  }
});

final usdBrlRateProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(resolvedBackendBtcRatesProvider);
  final rate = backendRates?.usdBrl;
  if (rate != null && rate > 0) return rate;
  return null;
});

/// Provider for BTC/EUR exchange rate (backend only).
final btcEurPriceProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(resolvedBackendBtcRatesProvider);
  final btcEur = backendRates?.btcEur;
  if (btcEur != null && btcEur > 0) {
    return btcEur;
  }
  return null;
});

/// Provider for BTC/BRL exchange rate (backend first).
final btcBrlPriceProvider = Provider.autoDispose<double?>((ref) {
  final backendRates = ref.watch(resolvedBackendBtcRatesProvider);
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
