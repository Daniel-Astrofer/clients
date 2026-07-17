import 'package:flutter/material.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/notification_translator.dart';

/// Android / iOS local-notification channels (must match createNotificationChannel ids).
abstract final class NativeNotificationChannels {
  static const transactions = 'kerosene_transactions';
  static const security = 'kerosene_security';
  static const system = 'kerosene_system';
  static const foreground = 'kerosene_foreground';

  static const transactionsName = 'Movimentações';
  static const securityName = 'Segurança';
  static const systemName = 'Sistema';
  static const foregroundName = 'Kerosene em segundo plano';

  static const transactionsDesc =
      'Recebimentos, envios e depósitos Bitcoin em tempo real.';
  static const securityDesc =
      'Login, recuperação e alertas críticos de conta.';
  static const systemDesc = 'Avisos gerais da plataforma Kerosene.';
  static const foregroundDesc =
      'Mantém o monitoramento de carteiras com o app em segundo plano.';
}

enum NativeNotificationFamily {
  transactionIncoming,
  transactionOutgoing,
  transactionPending,
  security,
  system,
}

/// Structured payload for the Android/iOS shade (not the in-app theater).
@immutable
class NativeNotificationPresentation {
  final String title;
  final String body;
  final String? summary;
  final String channelId;
  final NativeNotificationFamily family;
  final bool highPriority;
  final Color accentColor;
  final String? payload;
  final String dedupeKey;

  const NativeNotificationPresentation({
    required this.title,
    required this.body,
    required this.channelId,
    required this.family,
    required this.accentColor,
    required this.dedupeKey,
    this.summary,
    this.highPriority = true,
    this.payload,
  });

  bool get incoming =>
      family == NativeNotificationFamily.transactionIncoming ||
      family == NativeNotificationFamily.transactionPending;
}

/// Builds consistent native-alert copy from backend notification fields.
class NativeNotificationPresenter {
  const NativeNotificationPresenter();

  NativeNotificationPresentation present({
    required String id,
    required String kind,
    required String title,
    required String body,
    Map<String, String> metadata = const {},
    String? deeplink,
    String? entityType,
    String? entityId,
    String? severity,
  }) {
    final normalizedKind = kind.trim().toLowerCase();
    final family = _familyFor(normalizedKind);
    final channelId = switch (family) {
      NativeNotificationFamily.security => NativeNotificationChannels.security,
      NativeNotificationFamily.system => NativeNotificationChannels.system,
      _ => NativeNotificationChannels.transactions,
    };

    final network = _extractNetworkLabel(normalizedKind, metadata, title, body);

    final dummyItem = SessionNotificationItem(
      id: id,
      kind: normalizedKind,
      title: title,
      body: body,
      metadata: metadata,
      deeplink: deeplink,
      entityType: entityType,
      entityId: entityId,
      severity: severity ?? 'info',
      timestamp: DateTime.now(),
    );

    final resolvedTitle = NotificationTranslator.resolveTitle(null, dummyItem);
    final resolvedBody = NotificationTranslator.resolveBody(null, dummyItem);

    final composed = switch (family) {
      NativeNotificationFamily.transactionIncoming => (
          resolvedTitle,
          resolvedBody,
          network,
        ),
      NativeNotificationFamily.transactionOutgoing => (
          resolvedTitle,
          resolvedBody,
          network,
        ),
      NativeNotificationFamily.transactionPending => (
          resolvedTitle,
          resolvedBody,
          'Pendente',
        ),
      NativeNotificationFamily.security => (
          _shortTitle(resolvedTitle, fallback: 'Alerta de segurança'),
          _securityBody(resolvedBody),
          'Segurança',
        ),
      NativeNotificationFamily.system => (
          _shortTitle(resolvedTitle, fallback: 'Kerosene'),
          resolvedBody.trim().isEmpty ? 'Atualização da plataforma.' : resolvedBody.trim(),
          'Kerosene',
        ),
    };

    final dedupe = _dedupeKey(
      kind: normalizedKind,
      entityType: entityType,
      entityId: entityId,
      id: id,
      title: composed.$1,
      body: composed.$2,
    );

    return NativeNotificationPresentation(
      title: composed.$1,
      body: composed.$2,
      summary: composed.$3,
      channelId: channelId,
      family: family,
      highPriority: family != NativeNotificationFamily.system,
      accentColor: _accentFor(family, severity),
      payload: deeplink,
      dedupeKey: dedupe,
    );
  }

  /// From session notification entity (foreground WS path).
  NativeNotificationPresentation presentSession(
    SessionNotificationItem item,
  ) {
    return present(
      id: item.id,
      kind: item.kind,
      title: item.title,
      body: item.body,
      metadata: item.metadata,
      deeplink: item.deeplink,
      entityType: item.entityType,
      entityId: item.entityId,
      severity: item.severity,
    );
  }

  static bool isNativeAlertKind(String kind) {
    final k = kind.trim().toLowerCase();
    if (k.isEmpty) return false;
    final family = _familyFor(k);
    if (family == NativeNotificationFamily.security ||
        family == NativeNotificationFamily.transactionIncoming ||
        family == NativeNotificationFamily.transactionOutgoing ||
        family == NativeNotificationFamily.transactionPending) {
      return true;
    }
    // Explicit allow-list for a few system lifecycle alerts.
    return k == SessionNotificationItem.kindAccountCreated ||
        k == 'account_created';
  }

  static bool isFinancialKind(String kind) {
    final family = _familyFor(kind.trim().toLowerCase());
    return family == NativeNotificationFamily.transactionIncoming ||
        family == NativeNotificationFamily.transactionOutgoing ||
        family == NativeNotificationFamily.transactionPending;
  }

  static bool isSecurityKind(String kind) {
    return _familyFor(kind.trim().toLowerCase()) ==
        NativeNotificationFamily.security;
  }

  static NativeNotificationFamily _familyFor(String kind) {
    if (kind.contains('security') ||
        kind == SessionNotificationItem.kindSecurityLoginDetected ||
        kind == SessionNotificationItem.kindSecurityAdminAccessAttempt ||
        kind == SessionNotificationItem.kindSecurityRecoveryCompleted) {
      return NativeNotificationFamily.security;
    }
    if (kind == SessionNotificationItem.kindDepositDetected ||
        kind.contains('deposit_detected') ||
        kind.contains('pending') ||
        kind.contains('progress')) {
      return NativeNotificationFamily.transactionPending;
    }
    if (kind == SessionNotificationItem.kindTransferReceived ||
        kind == SessionNotificationItem.kindPaymentRequestPaid ||
        kind == SessionNotificationItem.kindDepositConfirmed ||
        kind.contains('received') ||
        kind.contains('inbound') ||
        kind.contains('deposit_confirmed') ||
        kind.contains('deposit')) {
      // deposit_confirmed is settled receive
      if (kind.contains('deposit_detected') || kind.contains('progress')) {
        return NativeNotificationFamily.transactionPending;
      }
      return NativeNotificationFamily.transactionIncoming;
    }
    if (kind == SessionNotificationItem.kindTransferSent ||
        kind == SessionNotificationItem.kindPaymentSent ||
        kind.contains('sent') ||
        kind.contains('outbound') ||
        kind.contains('broadcast')) {
      return NativeNotificationFamily.transactionOutgoing;
    }
    return NativeNotificationFamily.system;
  }


  static String _securityBody(String body) {
    final t = body.trim();
    if (t.isEmpty) {
      return 'Revise sessões ativas se não reconhece esta atividade.';
    }
    return t;
  }

  static String _shortTitle(String title, {required String fallback}) {
    final t = title.trim();
    if (t.isEmpty) return fallback;
    if (t.length <= 48) return t;
    return '${t.substring(0, 45)}…';
  }


  static String? _extractAmountLabel(
    Map<String, String> metadata,
    String body,
  ) {
    final rawBtc = metadata['amount'] ??
        metadata['amountBtc'] ??
        metadata['amount_btc'];
    if (rawBtc != null && rawBtc.trim().isNotEmpty) {
      return '${_trimZeros(rawBtc.trim())} BTC';
    }
    final satsRaw = metadata['creditedSats'] ??
        metadata['credited_sats'] ??
        metadata['amountSats'] ??
        metadata['amount_sats'];
    final sats = int.tryParse(satsRaw ?? '');
    if (sats != null && sats > 0) {
      return _formatSatsAsBtc(sats);
    }
    final match = RegExp(
      r'([\d]+(?:[.,][\d]+)?)\s*BTC',
      caseSensitive: false,
    ).firstMatch(body);
    if (match != null) {
      return '${_trimZeros(match.group(1)!.replaceAll(',', '.'))} BTC';
    }
    return null;
  }

  static String? _extractWalletLabel(
    Map<String, String> metadata,
    String body,
  ) {
    final fromMeta = metadata['walletName'] ??
        metadata['wallet_name'] ??
        metadata['walletLabel'] ??
        metadata['wallet_label'];
    if (fromMeta != null && fromMeta.trim().isNotEmpty) {
      return fromMeta.trim();
    }
    final quoted = RegExp(
      r'carteira\s+[“"]([^”"]+)[”"]',
      caseSensitive: false,
    ).firstMatch(body);
    if (quoted != null) return quoted.group(1)!.trim();
    return null;
  }

  static String _extractNetworkLabel(
    String kind,
    Map<String, String> metadata,
    String title,
    String body,
  ) {
    final rail = (metadata['rail'] ?? metadata['network'] ?? '')
        .trim()
        .toUpperCase();
    if (rail.contains('LIGHT')) return 'Lightning';
    if (rail.contains('ONCHAIN') || rail.contains('ON-CHAIN') || rail == 'BTC') {
      return 'On-chain';
    }
    if (rail.contains('INTERNAL')) return 'Interna';

    final combined = '$title $body $kind'.toLowerCase();
    if (combined.contains('lightning')) return 'Lightning';
    if (combined.contains('cold') || combined.contains('fria')) {
      return 'Cold · on-chain';
    }
    if (combined.contains('on-chain') ||
        combined.contains('onchain') ||
        combined.contains('depósito') ||
        combined.contains('deposito')) {
      return 'On-chain';
    }
    if (kind.contains('transfer_received') ||
        kind.contains('transfer_sent') ||
        combined.contains('interna')) {
      return 'Interna';
    }
    return 'Bitcoin';
  }

  static String _formatSatsAsBtc(int sats) {
    var raw = (sats / 100000000.0).toStringAsFixed(8);
    raw = _trimZeros(raw);
    return '$raw BTC';
  }

  static String _trimZeros(String amount) {
    var value = amount;
    if (value.contains('.')) {
      value = value.replaceAll(RegExp(r'0+$'), '');
      if (value.endsWith('.')) {
        value = value.substring(0, value.length - 1);
      }
    }
    return value;
  }

  static Color _accentFor(NativeNotificationFamily family, String? severity) {
    final sev = (severity ?? '').toLowerCase();
    if (sev == 'error' || sev == 'warning') {
      return family == NativeNotificationFamily.security
          ? KeroseneBrandTokens.warning
          : KeroseneBrandTokens.warning;
    }
    return switch (family) {
      NativeNotificationFamily.transactionIncoming =>
        KeroseneBrandTokens.success,
      NativeNotificationFamily.transactionPending =>
        KeroseneBrandTokens.bitcoin,
      NativeNotificationFamily.transactionOutgoing =>
        KeroseneBrandTokens.warning,
      NativeNotificationFamily.security => KeroseneBrandTokens.warning,
      NativeNotificationFamily.system => KeroseneBrandTokens.brand,
    };
  }

  static String _dedupeKey({
    required String kind,
    required String? entityType,
    required String? entityId,
    required String id,
    required String title,
    required String body,
  }) {
    if (entityType != null &&
        entityType.isNotEmpty &&
        entityId != null &&
        entityId.isNotEmpty) {
      return '$kind|$entityType|$entityId';
    }
    if (id.isNotEmpty) return id;
    return '${title.trim().toLowerCase()}|${body.trim().toLowerCase()}';
  }
}
