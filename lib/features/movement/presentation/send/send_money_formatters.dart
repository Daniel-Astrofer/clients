import 'package:flutter/widgets.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

String sendShortHash(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 18) return trimmed;
  return '${trimmed.substring(0, 10)}...${trimmed.substring(trimmed.length - 8)}';
}

bool isValidInternalDestination(String value) {
  final trimmed = normalizeInternalDestination(value);
  if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('bitcoin:')) {
    return false;
  }
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  final username = RegExp(r'^[a-z0-9_]{3,30}$');
  return uuid.hasMatch(trimmed) || username.hasMatch(trimmed);
}

String normalizeInternalDestination(String value) {
  var trimmed = value.trim();
  while (trimmed.startsWith('@')) {
    trimmed = trimmed.substring(1).trim();
  }
  return trimmed.toLowerCase();
}

String compactInternalValue(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 18) return trimmed;
  return '${trimmed.substring(0, 10)}...${trimmed.substring(trimmed.length - 6)}';
}

String recentInternalDestinationTitle(
    RecentTransactionDestination destination) {
  final label = _stripLeadingAt(destination.label);
  final address = _stripLeadingAt(destination.address);
  return label == null || label.isEmpty
      ? address ?? destination.address
      : label;
}

String recentInternalDestinationSubtitle(
    RecentTransactionDestination destination) {
  final label = _stripLeadingAt(destination.label);
  if (label == null || label.isEmpty) {
    return _recentInternalDestinationKindLabel(destination.kind);
  }
  return compactInternalValue(
      _stripLeadingAt(destination.address) ?? destination.address);
}

String? _stripLeadingAt(String? value) {
  var trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return trimmed;
  while (trimmed!.startsWith('@')) {
    trimmed = trimmed.substring(1).trim();
  }
  return trimmed;
}

String recentDestinationKindLabel(
  RecentTransactionDestinationKind kind, {
  BuildContext? context,
}) {
  if (context != null) {
    return switch (kind) {
      RecentTransactionDestinationKind.internal =>
        SendMoneyCopy.destinationKindInternal(context),
      RecentTransactionDestinationKind.onChain =>
        SendMoneyCopy.destinationKindOnchain(context),
      RecentTransactionDestinationKind.lightning =>
        SendMoneyCopy.destinationKindLightning(context),
    };
  }
  return switch (kind) {
    RecentTransactionDestinationKind.internal => 'Transferência interna',
    RecentTransactionDestinationKind.onChain => 'Endereço on-chain',
    RecentTransactionDestinationKind.lightning => 'Invoice Lightning',
  };
}

String _recentInternalDestinationKindLabel(
    RecentTransactionDestinationKind kind) {
  return recentDestinationKindLabel(kind);
}

String formatBtcValue(double value,
    {int decimalPlaces = 8, Locale? appLocale}) {
  return MoneyDisplay.format(
    amount: value,
    currency: Currency.btc,
    withSymbol: false,
    decimalPlaces: decimalPlaces,
    appLocale: appLocale,
  );
}

String walletBalanceLabel(double value) {
  return '${formatBtcValue(value, decimalPlaces: 6)} BTC';
}

/// Secondary fiat line next to a BTC amount.
///
/// Defaults fiat from [appLocale] when [fiatCurrency] is omitted
/// (pt→BRL, es→EUR, else USD) so send review is not stuck on BRL for EN users.
Currency preferredFiatForLocale(Locale? locale) {
  return switch (locale?.languageCode) {
    'pt' => Currency.brl,
    'es' => Currency.eur,
    _ => Currency.usd,
  };
}

String formatFiatReference({
  required double btcAmount,
  required double? btcUsd,
  required double? btcEur,
  required double? btcBrl,
  bool includeApproxPrefix = true,
  Currency? fiatCurrency,
  Locale? appLocale,
}) {
  final currency = fiatCurrency ?? preferredFiatForLocale(appLocale);
  final value = MoneyDisplay.formatAmountFromBtc(
    btcAmount: btcAmount,
    currency: currency,
    btcUsd: btcUsd,
    btcEur: btcEur,
    btcBrl: btcBrl,
    appLocale: appLocale,
  );
  return includeApproxPrefix ? '≈ $value' : value;
}

String estimatedSendTime(
  SendDestinationAnalysis destination, {
  int? estimatedSeconds,
  bool testnetLike = false,
}) {
  if (destination.isOnChain) {
    if (estimatedSeconds == null || estimatedSeconds <= 0) {
      return testnetLike ? '~20+ min · testnet varia' : '~10 min';
    }
    final minutes = (estimatedSeconds / 60).ceil();
    final String base;
    if (minutes < 60) {
      base = '~$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      base = remainingMinutes == 0
          ? '~$hours h'
          : '~$hours h $remainingMinutes min';
    }
    return testnetLike ? '$base · no testnet o tempo varia' : base;
  }
  if (destination.isLightning) return 'Segundos';
  return 'Instantâneo';
}
