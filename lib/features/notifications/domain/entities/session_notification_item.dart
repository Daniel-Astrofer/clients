import 'package:equatable/equatable.dart';
import 'dart:convert';

import 'package:kerosene/core/utils/app_date_time.dart';

enum NotificationPresentationPolicy {
  autoDismiss,
  persistUntilSeen,
  persistUntilAction,
}

class SessionNotificationItem extends Equatable {
  static const severityInfo = 'info';
  static const severitySuccess = 'success';
  static const severityWarning = 'warning';
  static const severityError = 'error';

  static const kindSystemInfo = 'system_info';
  static const kindSecurityLoginDetected = 'security_login_detected';
  static const kindSecurityAdminAccessAttempt = 'security_admin_access_attempt';
  static const kindSecurityRecoveryCompleted = 'security_recovery_completed';
  static const kindAccountCreated = 'account_created';
  static const kindTransferReceived = 'transfer_received';
  static const kindTransferSent = 'transfer_sent';
  static const kindPaymentRequestCreated = 'payment_request_created';
  static const kindPaymentRequestPaid = 'payment_request_paid';
  static const kindDepositDetected = 'deposit_detected';
  static const kindDepositConfirmed = 'deposit_confirmed';
  static const kindPaymentSent = 'payment_sent';
  static const kindLightningInvoicePaid = 'lightning_invoice_paid';
  static const kindLightningPaymentSent = 'lightning_payment_sent';
  static const kindLightningPaymentFailed = 'lightning_payment_failed';
  static const kindMarketAlert = 'market_alert';
  static const kindBackgroundAlertsSetup = 'background_alerts_setup';

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String kind;
  final String severity;
  final String? deeplink;
  final String? entityType;
  final String? entityId;
  final Map<String, String> metadata;
  final bool read;

  const SessionNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.kind = kindSystemInfo,
    this.severity = severityInfo,
    this.deeplink,
    this.entityType,
    this.entityId,
    this.metadata = const {},
    this.read = false,
  });

  factory SessionNotificationItem.fromJson(Map<String, dynamic> json) {
    final metadata = <String, String>{..._parseMetadata(json['metadata'])};
    for (final key in const [
      'amount',
      'currency',
      'status',
      'expiresAt',
      'presentationPolicy',
    ]) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        metadata.putIfAbsent(key, () => value.trim());
      }
    }
    return SessionNotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      timestamp: _parseDateTime(
            json['timestamp'] ?? json['createdAt'],
          ) ??
          DateTime.now(),
      kind: json['kind']?.toString() ?? kindSystemInfo,
      severity: json['severity']?.toString() ?? severityInfo,
      deeplink: json['deeplink']?.toString(),
      entityType: json['entityType']?.toString(),
      entityId: json['entityId']?.toString(),
      metadata: metadata,
      read: json['read'] == true || json['isRead'] == true,
    );
  }

  String get dedupeKey {
    final explicitDedupe = metadata['dedupeKey'];
    if (explicitDedupe != null && explicitDedupe.trim().isNotEmpty) {
      return explicitDedupe.trim();
    }

    if (entityType != null &&
        entityType!.isNotEmpty &&
        entityId != null &&
        entityId!.isNotEmpty) {
      return '$kind|$entityType|$entityId';
    }
    return id;
  }

  bool get isActionable => deeplink != null && deeplink!.trim().isNotEmpty;
  bool get canSyncRead => int.tryParse(id) != null;

  /// Priority is intentionally derived from the domain kind, rather than from
  /// presentation code. This keeps money and security events ahead of
  /// editorial/educational content wherever they are rendered.
  int get presentationPriority {
    if (isSecurityEvent) return 400;
    if (isFinancialEvent) return 300;
    if (severity == severityError || severity == severityWarning) return 200;
    if (kind == kindMarketAlert) return 100;
    return 50;
  }

  bool get isSecurityEvent => kind.startsWith('security_');

  bool get isFinancialEvent => const {
        kindTransferReceived,
        kindTransferSent,
        kindPaymentRequestCreated,
        kindPaymentRequestPaid,
        kindDepositDetected,
        kindDepositConfirmed,
        kindPaymentSent,
        kindLightningInvoicePaid,
        kindLightningPaymentSent,
        kindLightningPaymentFailed,
      }.contains(kind);

  bool get shouldPersistBanner =>
      isSecurityEvent || isFinancialEvent || severity == severityError;

  NotificationPresentationPolicy get presentationPolicy {
    if (shouldPersistBanner) {
      return isActionable
          ? NotificationPresentationPolicy.persistUntilAction
          : NotificationPresentationPolicy.persistUntilSeen;
    }
    return NotificationPresentationPolicy.autoDismiss;
  }

  SessionNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    String? kind,
    String? severity,
    String? deeplink,
    String? entityType,
    String? entityId,
    Map<String, String>? metadata,
    bool? read,
  }) {
    return SessionNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      kind: kind ?? this.kind,
      severity: severity ?? this.severity,
      deeplink: deeplink ?? this.deeplink,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadata: metadata ?? this.metadata,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'kind': kind,
      'severity': severity,
      'deeplink': deeplink,
      'entityType': entityType,
      'entityId': entityId,
      'metadata': metadata,
      'read': read,
    };
  }

  static Map<String, String> _parseMetadata(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value).map(
        (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
      );
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded).map(
            (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
          );
        }
      } catch (_) {}
    }

    return const {};
  }

  static DateTime? _parseDateTime(Object? value) {
    // Backend timestamps are Zulu (Instant / UTC). AppDateTime converts to device local.
    return AppDateTime.parse(value);
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        timestamp,
        kind,
        severity,
        deeplink,
        entityType,
        entityId,
        metadata.toString(),
        read,
      ];
}
