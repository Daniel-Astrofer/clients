import 'package:equatable/equatable.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

/// Entidade PaymentLink — solicitação de recebimento Bitcoin.
class PaymentLink extends Equatable {
  final String id;
  final int userId;
  final String? sessionId;
  final double amountBtc;
  final double grossAmountBtc;
  final double depositFeeBtc;
  final double netAmountBtc;
  final String description;
  final String depositAddress;
  final String visibility;
  final String confirmationMode;
  final bool amountLocked;
  final String? referenceLabel;
  final Map<String, String> metadata;
  final String? destinationHash;
  final String? paymentUri;
  final bool locked;
  final String status;
  final String? txid;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String paymentRail;
  final String settlementStatus;
  final String? settlementReference;
  final bool terminal;
  final int confirmations;
  /// BOLT11 invoice when [paymentRail] is LIGHTNING.
  final String? paymentRequest;
  final String? paymentHash;

  const PaymentLink({
    required this.id,
    required this.userId,
    this.sessionId,
    required this.amountBtc,
    this.grossAmountBtc = 0,
    this.depositFeeBtc = 0,
    this.netAmountBtc = 0,
    required this.description,
    required this.depositAddress,
    this.visibility = 'PRIVATE',
    this.confirmationMode = 'USER_ACTION_REQUIRED',
    this.amountLocked = true,
    this.referenceLabel,
    this.metadata = const {},
    this.destinationHash,
    this.paymentUri,
    this.locked = false,
    required this.status,
    this.txid,
    this.expiresAt,
    this.createdAt,
    this.paidAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.paymentRail = 'ONCHAIN',
    this.settlementStatus = 'QUOTED',
    this.settlementReference,
    this.terminal = false,
    this.confirmations = 0,
    this.paymentRequest,
    this.paymentHash,
  });

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isCompleted => status == 'completed';
  bool get isVerifyingOnboarding => status == 'verifying_onboarding';
  bool get isCancelled =>
      status == 'cancelled' || status == 'canceled' || status == 'hidden';
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && DateTime.now().isAfter(expiresAt!));
  bool get isValidatingSettlement =>
      settlementStatus == 'VALIDATING' ||
      settlementStatus == 'QUORUM_SYNC' ||
      settlementStatus == 'EXECUTING';
  bool get hasObservedOnchainPayment =>
      isValidatingSettlement || (txid != null && txid!.trim().isNotEmpty);
  String get displayStatus {
    if (isValidatingSettlement) {
      return settlementStatus;
    }
    if (hasObservedOnchainPayment && isPending) {
      return 'DETECTED';
    }
    return status;
  }

  bool get isInternalPaymentRequest =>
      locked || (destinationHash != null && destinationHash!.isNotEmpty);

  bool get isLightningPaymentRequest =>
      paymentRail.toUpperCase().contains('LIGHTNING') ||
      (paymentRequest != null &&
          paymentRequest!.trim().toLowerCase().startsWith('ln'));

  /// Payload shown in QR / share: bolt11, BIP-21 URI, or address.
  String get shareablePaymentPayload {
    final bolt11 = paymentRequest?.trim();
    if (bolt11 != null && bolt11.isNotEmpty) return bolt11;
    final uri = paymentUri?.trim();
    if (uri != null && uri.isNotEmpty) return uri;
    return depositAddress.trim();
  }

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    double amountBtc = (data['amountBtc'] as num?)?.toDouble() ?? 0;
    if (amountBtc == 0) {
      final amountSats = (data['amountSats'] as num?)?.toDouble() ??
          (data['receiverAmountSats'] as num?)?.toDouble() ??
          (data['grossAmountSats'] as num?)?.toDouble();
      if (amountSats != null && amountSats > 0) {
        amountBtc = amountSats / 100000000.0;
      }
    }
    if (amountBtc == 0 && data['amount'] is num) {
      amountBtc = (data['amount'] as num).toDouble();
    }
    final grossAmountBtc =
        (data['grossAmountBtc'] as num?)?.toDouble() ?? amountBtc;
    final depositFeeBtc = (data['depositFeeBtc'] as num?)?.toDouble() ?? 0;
    final netAmountBtc =
        (data['netAmountBtc'] as num?)?.toDouble() ?? amountBtc;

    final rawStatus = data['status']?.toString() ?? 'pending';
    final rawSettlementStatus =
        data['settlementStatus']?.toString().toUpperCase();
    final normalizedStatus = _normalizeStatus(
      rawStatus,
      txid: data['txid']?.toString() ?? data['blockchainTxid']?.toString(),
      settlementStatus: rawSettlementStatus,
    );
    final settlementStatus =
        rawSettlementStatus ?? _settlementStatusFor(normalizedStatus);

    return PaymentLink(
      id: data['id']?.toString() ??
          data['transactionId']?.toString() ??
          data['providerReference']?.toString() ??
          '',
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      sessionId: data['sessionId']?.toString(),
      amountBtc: amountBtc,
      grossAmountBtc: grossAmountBtc,
      depositFeeBtc: depositFeeBtc,
      netAmountBtc: netAmountBtc,
      description:
          data['description']?.toString() ?? data['memo']?.toString() ?? '',
      depositAddress: data['depositAddress']?.toString() ??
          data['address']?.toString() ??
          data['activeAddress']?.toString() ??
          data['externalReference']?.toString() ??
          '',
      visibility: data['visibility']?.toString().toUpperCase() ?? 'PRIVATE',
      confirmationMode: data['confirmationMode']?.toString().toUpperCase() ??
          'USER_ACTION_REQUIRED',
      amountLocked: _parseBool(data['amountLocked'], fallback: true),
      referenceLabel: data['referenceLabel']?.toString(),
      metadata: _parseMetadata(data['metadata']),
      destinationHash: _readString(data, const [
        'destinationHash',
        'destination_hash',
        'addressHash',
        'address_hash',
        'walletHash',
        'wallet_hash',
      ]),
      paymentUri: data['paymentUri']?.toString(),
      locked: _parseBool(data['locked']),
      status: normalizedStatus,
      txid: data['txid']?.toString() ?? data['blockchainTxid']?.toString(),
      expiresAt: data['expiresAt'] != null
          ? DateTime.tryParse(data['expiresAt'].toString())
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
      paidAt: data['paidAt'] != null
          ? DateTime.tryParse(data['paidAt'].toString())
          : null,
      completedAt: data['completedAt'] != null
          ? DateTime.tryParse(data['completedAt'].toString())
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? DateTime.tryParse(data['cancelledAt'].toString())
          : null,
      cancelReason: data['cancelReason']?.toString(),
      paymentRail: data['paymentRail']?.toString().toUpperCase() ??
          data['rail']?.toString().toUpperCase() ??
          'ONCHAIN',
      settlementStatus: settlementStatus,
      settlementReference: data['settlementReference']?.toString(),
      terminal: _parseBool(
        data['terminal'],
        fallback: _terminalSettlementStatus(settlementStatus),
      ),
      confirmations: (data['confirmations'] as num?)?.toInt() ??
          (data['confirmationCount'] as num?)?.toInt() ??
          0,
      paymentRequest: data['paymentRequest']?.toString() ??
          data['payment_request']?.toString() ??
          data['bolt11']?.toString() ??
          metadataPaymentRequest(data),
      paymentHash: data['paymentHash']?.toString() ??
          data['payment_hash']?.toString(),
    );
  }

  static String? metadataPaymentRequest(Map<String, dynamic> data) {
    final meta = data['metadata'];
    if (meta is Map) {
      final value = meta['paymentRequest'] ?? meta['payment_request'];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        sessionId,
        amountBtc,
        grossAmountBtc,
        depositFeeBtc,
        netAmountBtc,
        description,
        depositAddress,
        visibility,
        confirmationMode,
        amountLocked,
        referenceLabel,
        metadata,
        destinationHash,
        paymentUri,
        locked,
        status,
        txid,
        expiresAt,
        createdAt,
        paidAt,
        completedAt,
        cancelledAt,
        cancelReason,
        paymentRail,
        settlementStatus,
        settlementReference,
        terminal,
        confirmations,
        paymentRequest,
        paymentHash,
      ];

  /// Converte PaymentLink para Transaction para exibição no histórico unificado
  Transaction toTransaction() {
    final railUpper = paymentRail.toUpperCase();
    final isInternalRail =
        railUpper.contains('INTERNAL') || isInternalPaymentRequest;
    final isLightningRail = railUpper.contains('LIGHTNING');
    final isOnchain = !isInternalRail &&
        !isLightningRail &&
        (railUpper.contains('ONCHAIN') ||
            depositAddress.trim().isNotEmpty ||
            railUpper.isEmpty);
    final bool isCompleted = status == 'completed' ||
        terminal ||
        (isInternalRail && status == 'paid') ||
        (!isOnchain && status == 'paid') ||
        (isOnchain && status == 'paid' && confirmations >= 3);
    final bool cancelledOrExpired = isCancelled || isExpired;
    final railLabel = isInternalRail
        ? 'interno'
        : isLightningRail
            ? 'Lightning'
            : 'on-chain';
    final transactionDescription = cancelledOrExpired
        ? (isExpired && !isCancelled
            ? 'Link de pagamento expirado ($railLabel)'
            : 'Link de pagamento cancelado ($railLabel)')
        : description.isNotEmpty
            ? description
            : 'Link de pagamento ($railLabel)';
    final hasObservedOnchainPayment = isOnchain &&
        txid != null &&
        txid!.trim().isNotEmpty &&
        !cancelledOrExpired &&
        !isCompleted;
    final resolvedRail = isInternalRail
        ? 'INTERNAL'
        : isLightningRail
            ? 'LIGHTNING'
            : 'ONCHAIN';

    final bolt11 = paymentRequest?.trim();
    final hash = paymentHash?.trim();
    final displayDestination = isLightningRail && bolt11 != null && bolt11.isNotEmpty
        ? bolt11
        : depositAddress.isNotEmpty
            ? depositAddress
            : (referenceLabel?.trim().isNotEmpty == true
                ? referenceLabel!.trim()
                : 'Carteira receptora');

    return Transaction(
      id: "pl_$id",
      fromAddress: isInternalRail
          ? 'Kerosene'
          : isLightningRail
              ? 'Lightning'
              : 'Rede Bitcoin',
      toAddress: displayDestination,
      amountSatoshis: (amountBtc * 100000000).round(),
      feeSatoshis: 0,
      status: isCompleted
          ? TransactionStatus.confirmed
          : cancelledOrExpired
              ? TransactionStatus.cancelled
              : hasObservedOnchainPayment
                  ? TransactionStatus.confirming
                  : TransactionStatus.pending,
      type: TransactionType.receive,
      // Lightning has no block confirmations (HTLC settles instantly).
      confirmations: isLightningRail
          ? 0
          : isCompleted
              ? (confirmations > 0 ? confirmations : 3)
              : confirmations,
      timestamp: createdAt ?? DateTime.now(),
      description: transactionDescription,
      isInternal: isInternalRail,
      isLightning: isLightningRail,
      rail: resolvedRail,
      provider: 'PAYMENT_LINK',
      blockchainTxid:
          txid == null || txid!.trim().isEmpty ? null : txid!.trim(),
      paymentHash: hash != null && hash.isNotEmpty ? hash : null,
      lightningInvoice: bolt11 != null && bolt11.isNotEmpty ? bolt11 : null,
      externalReference: isLightningRail
          ? (hash != null && hash.isNotEmpty
              ? hash
              : (bolt11 != null && bolt11.isNotEmpty
                  ? bolt11
                  : settlementReference))
          : depositAddress.isNotEmpty
              ? depositAddress
              : settlementReference,
    );
  }

  static String _settlementStatusFor(String status) {
    switch (status) {
      case 'pending':
        return 'QUOTED';
      case 'paid':
      case 'completed':
        return 'SETTLED';
      case 'expired':
        return 'EXPIRED';
      case 'cancelled':
      case 'canceled':
        return 'CANCELED';
      case 'verifying_onboarding':
      case 'verifying_activation':
        return 'PROCESSING';
      default:
        return 'REQUIRES_RECONCILIATION';
    }
  }

  static String _normalizeStatus(
    String status, {
    String? txid,
    String? settlementStatus,
  }) {
    final normalized = status.trim().toUpperCase();
    final hasTxid = txid != null && txid.trim().isNotEmpty;
    if (settlementStatus == 'VALIDATING' ||
        settlementStatus == 'QUORUM_SYNC' ||
        settlementStatus == 'EXECUTING' ||
        (hasTxid &&
            (normalized == 'OPEN' ||
                normalized == 'ACTIVE' ||
                normalized == 'PENDING' ||
                normalized == 'CREATED'))) {
      return 'pending';
    }
    switch (normalized) {
      case 'OPEN':
      case 'ACTIVE':
      case 'PENDING':
      case 'CREATED':
      case 'IDENTIFIED':
        return 'pending';
      case 'SETTLED':
      case 'PAID':
        return 'paid';
      case 'COMPLETED':
      case 'CONFIRMED':
        return 'completed';
      case 'EXPIRED':
        return 'expired';
      case 'CANCELED':
      case 'CANCELLED':
      case 'HIDDEN':
        return 'cancelled';
      case 'FAILED':
        return 'failed';
      default:
        return normalized.toLowerCase();
    }
  }

  static bool _terminalSettlementStatus(String status) {
    return status == 'SETTLED' ||
        status == 'FAILED' ||
        status == 'CANCELED' ||
        status == 'EXPIRED';
  }

  static bool _parseBool(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }
    return fallback;
  }

  static Map<String, String> _parseMetadata(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value).map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    return const {};
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
