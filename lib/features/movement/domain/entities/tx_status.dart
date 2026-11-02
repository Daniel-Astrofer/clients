import 'package:equatable/equatable.dart';

/// Status de uma transação Bitcoin na blockchain
class TxStatus extends Equatable {
  final String txid;
  final String? transactionId;
  final DateTime? occurredAt;
  final DateTime? updatedAt;
  final bool hasAmount;
  final bool hasNetworkFee;
  final bool hasPlatformFee;
  final bool hasTotalDebited;
  final String status;
  final int feeSatoshis;
  final double amountReceived;
  final double networkFeeBtc;
  final double platformFeeBtc;
  final double totalDebitedBtc;
  final String sender;
  final String receiver;
  final String? context;

  /// Mensagem retornada pelo servidor (sucesso ou erro)
  final String? message;

  const TxStatus({
    required this.txid,
    this.transactionId,
    this.occurredAt,
    this.updatedAt,
    this.hasAmount = false,
    this.hasNetworkFee = false,
    this.hasPlatformFee = false,
    this.hasTotalDebited = false,
    required this.status,
    required this.feeSatoshis,
    required this.amountReceived,
    this.networkFeeBtc = 0,
    this.platformFeeBtc = 0,
    this.totalDebitedBtc = 0,
    this.sender = '',
    this.receiver = '',
    this.context,
    this.message,
  });

  bool get isConfirmed => const {
        'confirmed',
        'completed',
        'settled',
        'paid',
      }.contains(status.toLowerCase());
  bool get isBroadcasted => const {
        'broadcasted',
        'accepted',
        'pending',
      }.contains(status.toLowerCase());

  factory TxStatus.fromJson(Map<String, dynamic> json) {
    // Handle nested legacy data and direct KFE transaction responses.
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final senderField = [data['sender'], data['from'], data['fromAddress']]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

    final receiverField = [data['receiver'], data['to'], data['toAddress']]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
    final networkFeeSats = (data['networkFeeSats'] as num?)?.toInt();
    final keroseneFeeSats = (data['keroseneFeeSats'] as num?)?.toInt();
    final rawReceiverAmountSats = (data['receiverAmountSats'] as num?)?.toInt();
    final rawGrossAmountSats = (data['grossAmountSats'] as num?)?.toInt() ??
        (data['amountSats'] as num?)?.toInt() ??
        (data['amountSatoshis'] as num?)?.toInt();
    final receiverAmountSats = rawReceiverAmountSats ?? rawGrossAmountSats;
    final totalDebitSats = (data['totalDebitSats'] as num?)?.toInt();

    return TxStatus(
      txid: data['txid']?.toString() ??
          data['blockchainTxid']?.toString() ??
          data['externalReference']?.toString() ??
          data['id']?.toString() ??
          '',
      transactionId:
          data['id']?.toString() ?? data['transactionId']?.toString(),
      occurredAt: _serverTime(data['createdAt'] ?? data['timestamp']),
      updatedAt: _serverTime(data['updatedAt']),
      hasAmount: receiverAmountSats != null ||
          data['amount'] != null ||
          data['amountReceived'] != null ||
          data['amountBtc'] != null,
      hasNetworkFee:
          data['networkFeeSats'] != null || data['networkFeeBtc'] != null,
      hasPlatformFee:
          data['keroseneFeeSats'] != null || data['platformFeeBtc'] != null,
      hasTotalDebited:
          data['totalDebitSats'] != null || data['totalDebitedBtc'] != null,
      status: data['status']?.toString() ?? 'unknown',
      feeSatoshis: (data['feeSatoshis'] as num?)?.toInt() ??
          (networkFeeSats == null
              ? null
              : networkFeeSats + (keroseneFeeSats ?? 0)) ??
          (((data['networkFeeBtc'] as num?)?.toDouble() ?? 0) * 100000000)
              .round(),
      amountReceived: receiverAmountSats == null
          ? ((data['amount'] as num?)?.toDouble() ??
              (data['amountReceived'] as num?)?.toDouble() ??
              (data['amountBtc'] as num?)?.toDouble() ??
              0)
          : receiverAmountSats / 100000000.0,
      networkFeeBtc: networkFeeSats == null
          ? ((data['networkFeeBtc'] as num?)?.toDouble() ?? 0)
          : networkFeeSats / 100000000.0,
      platformFeeBtc: keroseneFeeSats == null
          ? ((data['platformFeeBtc'] as num?)?.toDouble() ?? 0)
          : keroseneFeeSats / 100000000.0,
      totalDebitedBtc: totalDebitSats == null
          ? ((data['totalDebitedBtc'] as num?)?.toDouble() ?? 0)
          : totalDebitSats / 100000000.0,
      sender: senderField ??
          data['sourceWalletId']?.toString() ??
          data['walletName']?.toString() ??
          '',
      receiver: receiverField ??
          data['destinationWalletId']?.toString() ??
          data['destination']?.toString() ??
          data['paymentRequest']?.toString() ??
          data['externalReference']?.toString() ??
          '',
      context: data['context']?.toString() ??
          data['description']?.toString() ??
          data['memo']?.toString(),
      message: json['message']?.toString(),
    );
  }

  static DateTime? _serverTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) {
      final milliseconds = raw > 20000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }
    final text = raw.toString().trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    // KFE's legacy LocalDateTime responses use a UTC server clock.
    return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
        parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
  }

  @override
  List<Object?> get props => [
        txid,
        transactionId,
        occurredAt,
        updatedAt,
        hasAmount,
        hasNetworkFee,
        hasPlatformFee,
        hasTotalDebited,
        status,
        feeSatoshis,
        amountReceived,
        networkFeeBtc,
        platformFeeBtc,
        totalDebitedBtc,
        sender,
        receiver,
        context,
        message,
      ];
}
