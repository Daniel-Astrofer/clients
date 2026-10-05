import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Pure helpers that turn financial events into home-theater receive pieces.
///
/// The theater used to depend only on STOMP notification kinds. Extrato/balance
/// can advance via REST poll without those notifications, so receives must also
/// be derivable from ledger rows and balance credits.

/// Compatible with both [Ref.read] and [WidgetRef.read].
typedef IncomingTheaterRead = T Function<T>(ProviderListenable<T> provider);

class IncomingTheaterPayload {
  final String id;
  final String amountLabel;
  final String walletName;
  final String networkLabel;
  final String? subtitle;

  const IncomingTheaterPayload({
    required this.id,
    required this.amountLabel,
    required this.walletName,
    required this.networkLabel,
    this.subtitle,
  });
}

/// Formats sats as a compact BTC label (e.g. `0.00123 BTC`).
String formatBtcAmountLabel(int amountSatoshis) {
  if (amountSatoshis <= 0) return 'fundos';
  var raw = (amountSatoshis / 100000000.0).toStringAsFixed(8);
  if (raw.contains('.')) {
    raw = raw.replaceAll(RegExp(r'0+$'), '');
    if (raw.endsWith('.')) {
      raw = raw.substring(0, raw.length - 1);
    }
  }
  if (raw.isEmpty || raw == '0') return 'fundos';
  return '$raw BTC';
}

String formatBtcAmountLabelFromBtc(double amountBtc) {
  if (amountBtc <= 0) return 'fundos';
  final sats = (amountBtc * 100000000).round();
  return formatBtcAmountLabel(sats);
}

/// Fiat-first label for in-app receive theater (e.g. `R$ 1.200,00`).
///
/// When the user prefers BTC, still show BRL so the description reads like
/// a bank credit — matches product copy for the home theater.
String formatIncomingTheaterAmount({
  required double amountBtc,
  required IncomingTheaterRead read,
}) {
  if (amountBtc <= 0) return 'fundos';
  final money = read(moneyFormatConfigProvider);
  final currency =
      money.currency == Currency.btc ? Currency.brl : money.currency;
  return MoneyDisplay.formatAmountFromBtc(
    btcAmount: amountBtc,
    currency: currency,
    btcUsd: read(latestBtcPriceProvider),
    btcEur: read(btcEurPriceProvider),
    btcBrl: read(btcBrlPriceProvider),
    withSymbol: true,
    appLocale: money.locale,
  );
}

String formatIncomingTheaterAmountFromSats({
  required int amountSatoshis,
  required IncomingTheaterRead read,
}) {
  return formatIncomingTheaterAmount(
    amountBtc: amountSatoshis / 100000000.0,
    read: read,
  );
}

String _trimTrailingZeros(String amount) {
  var value = amount.trim();
  if (value.contains('.')) {
    value = value.replaceAll(RegExp(r'0+$'), '');
    if (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
  }
  return value;
}

/// Pulls BTC amount text from notification metadata / body.
String extractNotificationAmount(SessionNotificationItem notification) {
  final meta = notification.metadata;
  final raw = meta['amount'] ?? meta['amountBtc'] ?? meta['amount_btc'] ?? '';
  if (raw.isNotEmpty) {
    return _trimTrailingZeros(raw);
  }

  final creditedSats = meta['creditedSats'] ??
      meta['credited_sats'] ??
      meta['amountSats'] ??
      meta['amount_sats'] ??
      '';
  final sats = int.tryParse(creditedSats);
  if (sats != null && sats > 0) {
    final label = formatBtcAmountLabel(sats);
    return label.endsWith(' BTC')
        ? label.substring(0, label.length - 4)
        : label;
  }

  final body = '${notification.title} ${notification.body}';
  final btcMatch = RegExp(r'([\d]+(?:[.,][\d]+)?)\s*BTC', caseSensitive: false)
      .firstMatch(body);
  if (btcMatch != null) {
    return _trimTrailingZeros(btcMatch.group(1)!.replaceAll(',', '.'));
  }
  return '';
}

String extractNotificationWalletName(SessionNotificationItem notification) {
  final meta = notification.metadata;
  final fromMeta = meta['walletName'] ??
      meta['wallet_name'] ??
      meta['walletLabel'] ??
      meta['wallet_label'] ??
      '';
  if (fromMeta.trim().isNotEmpty) return fromMeta.trim();

  final body = notification.body;
  // "na carteira “X”" / "carteira X"
  final quoted = RegExp(
    r'carteira\s+[“"]([^”"]+)[”"]',
    caseSensitive: false,
  ).firstMatch(body);
  if (quoted != null) return quoted.group(1)!.trim();

  final plain = RegExp(
    r'carteira\s+([A-Za-z0-9_\-\s]{1,40})',
    caseSensitive: false,
  ).firstMatch(body);
  if (plain != null) {
    final name = plain.group(1)!.trim();
    // Avoid swallowing the rest of the sentence.
    return name.split(RegExp(r'[.…]')).first.trim();
  }

  final emMatch =
      RegExp(r'em\s+([\w\s]{1,40})', caseSensitive: false).firstMatch(body);
  if (emMatch != null) return emMatch.group(1)!.trim();

  return 'Principal';
}

String extractNotificationNetworkLabel(SessionNotificationItem notification) {
  final rail =
      (notification.metadata['rail'] ?? notification.metadata['network'] ?? '')
          .trim()
          .toUpperCase();
  if (rail.contains('LIGHT')) return 'Lightning';
  if (rail.contains('ONCHAIN') || rail.contains('ON-CHAIN') || rail == 'BTC') {
    return 'Onchain';
  }
  if (rail.contains('INTERNAL') || rail.contains('LEDGER')) {
    return 'Interna';
  }

  if (notification.kind == SessionNotificationItem.kindDepositDetected ||
      notification.kind == SessionNotificationItem.kindDepositConfirmed) {
    final combined = '${notification.title} ${notification.body}'.toLowerCase();
    if (combined.contains('lightning')) return 'Lightning';
    return 'Onchain';
  }
  if (notification.kind == SessionNotificationItem.kindPaymentRequestPaid) {
    return 'Lightning';
  }
  if (notification.kind == SessionNotificationItem.kindTransferReceived) {
    return 'Interna';
  }
  return 'Interna';
}

bool isIncomingTransactionNotification(SessionNotificationItem notification) {
  return {
    SessionNotificationItem.kindTransferReceived,
    SessionNotificationItem.kindPaymentRequestPaid,
    SessionNotificationItem.kindDepositDetected,
    SessionNotificationItem.kindDepositConfirmed,
  }.contains(notification.kind);
}

IncomingTheaterPayload? payloadFromNotification(
  SessionNotificationItem notification, {
  IncomingTheaterRead? read,
}) {
  if (!isIncomingTransactionNotification(notification)) return null;

  final amountRaw = extractNotificationAmount(notification);
  String amountLabel;
  if (read != null && amountRaw.isNotEmpty) {
    final asBtc = double.tryParse(amountRaw.replaceAll(',', '.'));
    amountLabel = asBtc != null && asBtc > 0
        ? formatIncomingTheaterAmount(amountBtc: asBtc, read: read)
        : (amountRaw.contains(RegExp(r'[A-Za-z$€]'))
            ? amountRaw
            : '$amountRaw BTC');
  } else {
    amountLabel = amountRaw.isNotEmpty ? '$amountRaw BTC' : 'fundos';
  }
  // Prefer entityId (transaction UUID) so extrato path can dedupe the same receive.
  final entityId = (notification.entityId ?? '').trim();
  final id = entityId.isNotEmpty
      ? entityId
      : (notification.dedupeKey.isNotEmpty
          ? notification.dedupeKey
          : notification.id);

  return IncomingTheaterPayload(
    id: id,
    amountLabel: amountLabel,
    walletName: extractNotificationWalletName(notification),
    networkLabel: extractNotificationNetworkLabel(notification),
    subtitle: null,
  );
}

IncomingTheaterPayload? payloadFromTransaction(
  Transaction tx, {
  IncomingTheaterRead? read,
}) {
  if (!tx.isCredit || tx.isCancelled) return null;
  if (tx.amountSatoshis <= 0) return null;

  final network = switch (tx.normalizedRail) {
    'LIGHTNING' => 'Lightning',
    'INTERNAL' => 'Interna',
    'ONCHAIN' => 'Onchain',
    _ => tx.isLightning
        ? 'Lightning'
        : tx.isInternal
            ? 'Interna'
            : 'Onchain',
  };

  final wallet = (tx.walletLabel ??
          tx.destinationWalletLabel ??
          tx.receiverDisplayName ??
          '')
      .trim();

  final amountLabel = read != null
      ? formatIncomingTheaterAmountFromSats(
          amountSatoshis: tx.amountSatoshis,
          read: read,
        )
      : formatBtcAmountLabel(tx.amountSatoshis);

  return IncomingTheaterPayload(
    id: tx.id,
    amountLabel: amountLabel,
    walletName: wallet.isNotEmpty ? wallet : 'Principal',
    networkLabel: network,
    subtitle: null,
  );
}

/// True when a balance WS delta is a real inbound credit (not reserve unlock).
bool isInboundBalanceCredit({
  required double amountBtc,
  required String context,
}) {
  if (amountBtc <= 0.000000001) return false;
  final c = context.trim().toLowerCase();
  if (c.isEmpty) return false;
  if (c.contains('reserva') ||
      c.contains('liber') ||
      c.contains('débito') ||
      c.contains('debito') ||
      c.contains('liquid') ||
      c.contains('envio') ||
      c.contains('saque') ||
      c.contains('spend')) {
    return false;
  }
  return c.contains('crédito') ||
      c.contains('credito') ||
      c.contains('crédito observado') ||
      c.contains('credito observado') ||
      c.contains('deposit') ||
      c.contains('receb') ||
      // Cold inbound credit snapshot
      (c.contains('observado') && amountBtc > 0);
}

IncomingTheaterPayload? payloadFromBalanceCredit({
  required String walletId,
  required String walletName,
  required double amountBtc,
  required String context,
  String? kind,
  String? bucket,
  IncomingTheaterRead? read,
}) {
  if (!isInboundBalanceCredit(amountBtc: amountBtc, context: context)) {
    return null;
  }

  final network = () {
    final k = (kind ?? '').toUpperCase();
    final c = context.toLowerCase();
    final b = (bucket ?? '').toUpperCase();
    if (k.contains('LIGHT') || c.contains('lightning')) return 'Lightning';
    if (k.contains('WATCH') ||
        b == 'OBSERVED' ||
        c.contains('observado') ||
        c.contains('onchain') ||
        c.contains('on-chain')) {
      return 'Onchain';
    }
    if (k.contains('INTERNAL') || c.contains('interno')) return 'Interna';
    return 'Onchain';
  }();

  final name = walletName.trim().isNotEmpty ? walletName.trim() : 'Principal';
  final idSeed = walletId.trim().isNotEmpty ? walletId.trim() : name;
  // Stable enough for short-lived double fires (notif + balance).
  final amountKey = amountBtc.toStringAsFixed(8);
  final id = 'bal|$idSeed|$amountKey|${context.trim().toLowerCase()}';

  final amountLabel = read != null
      ? formatIncomingTheaterAmount(amountBtc: amountBtc, read: read)
      : formatBtcAmountLabelFromBtc(amountBtc);

  return IncomingTheaterPayload(
    id: id,
    amountLabel: amountLabel,
    walletName: name,
    networkLabel: network,
    subtitle: null,
  );
}

void presentIncomingTheater(
  HomeEducationQueue queue,
  HomeBalanceReceivePulse pulse,
  IncomingTheaterPayload payload,
) {
  enqueueIncomingTransfer(
    queue,
    pulse,
    id: payload.id,
    amountLabel: payload.amountLabel,
    walletName: payload.walletName,
    networkLabel: payload.networkLabel,
    subtitle: payload.subtitle,
  );
}
