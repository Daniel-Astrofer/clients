import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../providers/price_provider.dart';

class MoneyDisplay {
  const MoneyDisplay._();

  /// Hard cap for amount entry / calculator: 10 trillion (10 × 10¹²).
  static const double maxEditableAmount = 10000000000000;

  /// Bound from [MaterialApp] when the user changes language so every
  /// [format] / [formatCompact] call picks number separators from the app
  /// locale even when the caller omits [appLocale].
  static Locale? _boundAppLocale;

  /// Call from the app root whenever [localeProvider] changes.
  static void bindAppLocale(Locale locale) {
    _boundAppLocale = locale;
  }

  static Locale? get boundAppLocale => _boundAppLocale;

  static const List<Currency> pickerCurrencies = [
    Currency.btc,
    Currency.usd,
    Currency.eur,
    Currency.brl,
  ];

  static String symbolFor(Currency currency) {
    switch (currency) {
      case Currency.btc:
        return 'BTC';
      case Currency.usd:
        return 'US\$';
      case Currency.eur:
        return 'EUR';
      case Currency.brl:
        return 'R\$';
    }
  }

  static String tickerSymbolFor(Currency currency) {
    switch (currency) {
      case Currency.btc:
        return '₿';
      case Currency.usd:
        return 'US\$';
      case Currency.eur:
        return '€';
      case Currency.brl:
        return 'R\$';
    }
  }

  /// Number grouping / decimal separators follow the **app language** when
  /// [appLocale] is provided. Currency symbols always follow [currency].
  static String numberLocaleTag(Locale locale) {
    return switch (locale.languageCode.toLowerCase()) {
      'pt' => 'pt_BR',
      'es' => 'es_ES',
      _ => 'en_US',
    };
  }

  /// Currency-native default (legacy). Prefer [resolveNumberLocale] with app locale.
  static String localeFor(Currency currency) {
    switch (currency) {
      case Currency.btc:
      case Currency.usd:
        return 'en_US';
      case Currency.eur:
        return 'de_DE';
      case Currency.brl:
        return 'pt_BR';
    }
  }

  static String resolveNumberLocale(
    Currency currency, {
    Locale? appLocale,
  }) {
    final effective = appLocale ?? _boundAppLocale;
    if (effective != null) {
      return numberLocaleTag(effective);
    }
    return localeFor(currency);
  }

  static int decimalsFor(Currency currency) {
    switch (currency) {
      case Currency.btc:
        return 8;
      case Currency.usd:
      case Currency.eur:
      case Currency.brl:
        return 2;
    }
  }

  static double convertFromBtcAmount({
    required double btcAmount,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
  }) {
    return convertFromBtc(
      btcAmount,
      currency,
      btcUsd,
      btcEur,
      btcBrl,
    );
  }

  static double convertToBtcAmount({
    required double amount,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
  }) {
    return convertToBtc(
      amount,
      currency,
      btcUsd,
      btcEur,
      btcBrl,
    );
  }

  static String format({
    required double amount,
    required Currency currency,
    bool withSymbol = true,
    int? decimalPlaces,
    Locale? appLocale,
  }) {
    final decimals = decimalPlaces ?? decimalsFor(currency);
    final locale = resolveNumberLocale(currency, appLocale: appLocale);

    if (currency == Currency.btc) {
      final formatter = NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = decimals
        ..maximumFractionDigits = decimals;
      final value = formatter.format(amount);
      if (!withSymbol) {
        return value;
      }
      return '${tickerSymbolFor(currency)} $value';
    }

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: withSymbol ? '${symbolFor(currency)} ' : '',
      decimalDigits: decimals,
    );
    return formatter.format(amount).trim();
  }

  static String formatCompact({
    required double amount,
    required Currency currency,
    bool withSymbol = true,
    int? maxDecimalPlaces,
    Locale? appLocale,
  }) {
    final decimals = maxDecimalPlaces ?? decimalsFor(currency);
    final locale = resolveNumberLocale(currency, appLocale: appLocale);
    final formatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimals;
    final value = formatter.format(amount);

    if (!withSymbol) {
      return value;
    }

    final symbol = currency == Currency.btc
        ? tickerSymbolFor(currency)
        : symbolFor(currency);
    return '$symbol $value';
  }

  static double parseEditableInput(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty || normalized == '.') {
      return 0;
    }
    return double.tryParse(normalized) ?? 0;
  }

  static String formatEditableInput({
    required String rawValue,
    required Currency currency,
    bool withSymbol = true,
    Locale? appLocale,
  }) {
    final normalized = rawValue.trim().isEmpty ? '0' : rawValue.trim();
    final locale = resolveNumberLocale(currency, appLocale: appLocale);
    final formatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 0;
    final decimalSeparator = formatter.symbols.DECIMAL_SEP;
    final hasDecimal = normalized.contains('.');
    final hasTrailingDecimal = normalized.endsWith('.');
    final parts = normalized.split('.');
    final integerPart = parts.first.isEmpty ? '0' : parts.first;
    final decimalPart = parts.length > 1 ? parts[1] : '';
    final integerValue = int.tryParse(integerPart) ?? 0;

    var value = formatter.format(integerValue);
    if (hasDecimal) {
      value += decimalSeparator;
      if (!hasTrailingDecimal && decimalPart.isNotEmpty) {
        value += decimalPart;
      }
    }

    if (!withSymbol) {
      return value;
    }

    final symbol = currency == Currency.btc
        ? tickerSymbolFor(currency)
        : symbolFor(currency);
    return '$symbol $value';
  }

  static String rawInputFromAmount({
    required double amount,
    required Currency currency,
  }) {
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return _zeroRawInput(currency);
    }

    return amount.toStringAsFixed(decimalsFor(currency));
  }

  static String _zeroRawInput(Currency currency) {
    final decimals = decimalsFor(currency);
    if (decimals == 0) {
      return '0';
    }
    return '0.${'0' * decimals}';
  }

  static String applyKeypadInput({
    required String currentValue,
    required String key,
    required Currency currency,
    int maxLength = 16,
  }) {
    final current = currentValue.isEmpty ? '0' : currentValue;

    if (key == '←') {
      if (current.length <= 1) {
        return '0';
      }
      final updated = current.substring(0, current.length - 1);
      return updated.isEmpty ? '0' : updated;
    }

    if (key == '.') {
      if (decimalsFor(currency) == 0 || current.contains('.')) {
        return current;
      }
      final updated = '$current.';
      return updated.length <= maxLength ? updated : current;
    }

    if (!RegExp(r'^\d$').hasMatch(key)) {
      return current;
    }

    if (current.contains('.')) {
      final parts = current.split('.');
      if (parts.length > 1 && parts[1].length >= decimalsFor(currency)) {
        return current;
      }
    }

    if (current == '0') {
      return key == '0' ? '0' : key;
    }

    final updated = '$current$key';
    if (updated.length > maxLength) return current;
    if (parseEditableInput(updated) > maxEditableAmount) return current;
    return updated;
  }

  /// Normalize free-form system-keyboard input into keypad-style raw amount.
  static String sanitizeEditableInput({
    required String rawValue,
    required Currency currency,
    int maxLength = 16,
  }) {
    final decimals = decimalsFor(currency);
    var text = rawValue.trim().replaceAll(',', '.');
    text = text.replaceAll(RegExp(r'[^0-9.]'), '');

    if (text.isEmpty) return '0';

    final firstDot = text.indexOf('.');
    if (firstDot >= 0) {
      final before = text.substring(0, firstDot).replaceAll('.', '');
      var after = text.substring(firstDot + 1).replaceAll('.', '');
      if (decimals == 0) {
        text = before.isEmpty ? '0' : before;
      } else {
        if (after.length > decimals) {
          after = after.substring(0, decimals);
        }
        text = '${before.isEmpty ? '0' : before}.$after';
      }
    }

    // Strip leading zeros while preserving "0." / "0.xx".
    if (text.contains('.')) {
      final parts = text.split('.');
      var integer = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
      if (integer.isEmpty) integer = '0';
      text = '$integer.${parts.length > 1 ? parts[1] : ''}';
    } else {
      text = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      if (text.isEmpty) text = '0';
    }

    if (text.length > maxLength) {
      text = text.substring(0, maxLength);
    }

    final value = parseEditableInput(text);
    if (value > maxEditableAmount) {
      return rawFromMaxEditableAmount(currency);
    }
    return text;
  }

  /// Raw editable string for [maxEditableAmount] (no trailing zeros).
  static String rawFromMaxEditableAmount(Currency currency) {
    final decimals = decimalsFor(currency);
    if (decimals <= 0) {
      return maxEditableAmount.toStringAsFixed(0);
    }
    return maxEditableAmount.toStringAsFixed(0);
  }

  /// Clamp a numeric result into the editable amount range.
  static double clampEditableAmount(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0;
    if (value > maxEditableAmount) return maxEditableAmount;
    return value;
  }

  static String formatAmountFromBtc({
    required double btcAmount,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    bool withSymbol = true,
    bool signed = false,
    int? decimalPlaces,
    Locale? appLocale,
  }) {
    final value = convertFromBtcAmount(
      btcAmount: btcAmount,
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );
    final formatted = format(
      amount: value.abs(),
      currency: currency,
      withSymbol: withSymbol,
      decimalPlaces: decimalPlaces,
      appLocale: appLocale,
    );

    if (!signed) {
      return formatted;
    }

    final prefix = btcAmount >= 0 ? '+' : '-';
    return '$prefix$formatted';
  }

  static String formatFrozenAmountFromBtc({
    required double btcAmount,
    required Currency currency,
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
    Locale? appLocale,
  }) {
    final amount = _historicalAmount(
      btcAmount: btcAmount.abs(),
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: displayAmountUsd,
      displayAmountEur: displayAmountEur,
      displayAmountBrl: displayAmountBrl,
      displayBtcUsd: displayBtcUsd,
      displayBtcEur: displayBtcEur,
      displayBtcBrl: displayBtcBrl,
    );

    final formatted = format(
      amount: amount,
      currency: currency,
      withSymbol: withSymbol,
      appLocale: appLocale,
    );

    if (!signed) {
      return formatted;
    }

    final prefix = btcAmount >= 0 ? '+' : '-';
    return '$prefix$formatted';
  }

  static double _historicalAmount({
    required double btcAmount,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    double? displayAmountUsd,
    double? displayAmountEur,
    double? displayAmountBrl,
    double? displayBtcUsd,
    double? displayBtcEur,
    double? displayBtcBrl,
  }) {
    switch (currency) {
      case Currency.btc:
        return btcAmount;
      case Currency.usd:
        final frozen = displayAmountUsd;
        if (frozen != null && frozen != 0) return frozen.abs();
        return (displayBtcUsd != null && displayBtcUsd > 0
            ? btcAmount * displayBtcUsd
            : convertFromBtcAmount(
                btcAmount: btcAmount,
                currency: currency,
                btcUsd: btcUsd,
                btcEur: btcEur,
                btcBrl: btcBrl,
              ));
      case Currency.eur:
        final frozen = displayAmountEur;
        if (frozen != null && frozen != 0) return frozen.abs();
        return (displayBtcEur != null && displayBtcEur > 0
            ? btcAmount * displayBtcEur
            : convertFromBtcAmount(
                btcAmount: btcAmount,
                currency: currency,
                btcUsd: btcUsd,
                btcEur: btcEur,
                btcBrl: btcBrl,
              ));
      case Currency.brl:
        final frozen = displayAmountBrl;
        if (frozen != null && frozen != 0) return frozen.abs();
        return (displayBtcBrl != null && displayBtcBrl > 0
            ? btcAmount * displayBtcBrl
            : convertFromBtcAmount(
                btcAmount: btcAmount,
                currency: currency,
                btcUsd: btcUsd,
                btcEur: btcEur,
                btcBrl: btcBrl,
              ));
    }
  }

  static String formatQuote({
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
  }) {
    final quoteValue = formatQuoteValue(
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );

    if (quoteValue == null) {
      return currency == Currency.btc ? '' : 'Cotacao ao vivo indisponivel';
    }

    return 'BTC · $quoteValue';
  }

  static String? formatQuoteValue({
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
  }) {
    if (currency == Currency.btc) {
      return null;
    }

    final rate = convertFromBtcAmount(
      btcAmount: 1,
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
    );

    if (rate <= 0) {
      return null;
    }

    return format(amount: rate, currency: currency);
  }

  static Currency fallbackFiatFor(Currency currency) {
    switch (currency) {
      case Currency.btc:
        return Currency.brl;
      case Currency.usd:
      case Currency.eur:
      case Currency.brl:
        return Currency.btc;
    }
  }
}
