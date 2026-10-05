import 'package:equatable/equatable.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

/// A transfer observed or initiated through an external payment rail.
///
/// It retains provider identifiers and rail-specific values while exposing
/// [toTransaction] for the common activity feed. BTC amounts are converted to
/// satoshis only when projecting that shared transaction representation.
class ExternalTransfer extends Equatable {
  /// Stable transfer identifier assigned by the service.
  final String id;

  /// Rail name, usually `LIGHTNING` or `ONCHAIN`.
  final String network;

  /// Domain transfer category, such as outbound payment or inbound invoice.
  final String transferType;

  /// Current service lifecycle status for this transfer.
  final String status;

  /// External payment provider associated with the transfer.
  final String provider;

  /// User wallet name associated with the transfer.
  final String walletName;

  /// Payment destination, invoice, or address presented by the service.
  final String destination;

  /// Settled or submitted amount in BTC.
  final double amountBtc;

  /// Blockchain or Lightning network fee in BTC.
  final double networkFeeBtc;

  /// Platform fee in BTC.
  final double platformFeeBtc;

  /// Total sender debit in BTC after applicable fees.
  final double totalDebitedBtc;

  /// Provider-specific transfer reference.
  final String externalReference;

  /// Service identifier of the Lightning invoice, when applicable.
  final String invoiceId;

  /// On-chain transaction identifier, when observed.
  final String blockchainTxid;

  /// Lightning payment hash, when available.
  final String paymentHash;

  /// Encoded invoice payload retained for Lightning display or reconciliation.
  final String invoiceData;

  /// Expected incoming amount in BTC when the transfer is not yet settled.
  final double expectedAmountBtc;

  /// Number of on-chain confirmations currently observed.
  final int confirmations;

  /// Time the transfer was first detected by the service.
  final DateTime? detectedAt;

  /// Time the transfer reached its settled state.
  final DateTime? settledAt;

  /// Service creation timestamp.
  final DateTime? createdAt;

  /// Time of the most recent service update.
  final DateTime? updatedAt;

  /// Human-readable service context used as an activity description.
  final String context;

  /// Creates an immutable transfer from service-normalized values.
  const ExternalTransfer({
    required this.id,
    required this.network,
    required this.transferType,
    required this.status,
    required this.provider,
    required this.walletName,
    required this.destination,
    required this.amountBtc,
    required this.networkFeeBtc,
    required this.platformFeeBtc,
    required this.totalDebitedBtc,
    required this.externalReference,
    required this.invoiceId,
    required this.blockchainTxid,
    required this.paymentHash,
    required this.invoiceData,
    required this.expectedAmountBtc,
    required this.confirmations,
    required this.detectedAt,
    required this.settledAt,
    required this.createdAt,
    required this.updatedAt,
    required this.context,
  });

  /// Whether this transfer uses the Lightning rail.
  bool get isLightning => network.toUpperCase() == 'LIGHTNING';

  /// Whether this transfer uses the on-chain rail.
  bool get isOnchain => network.toUpperCase() == 'ONCHAIN';

  /// Whether the transfer sends value out of the user's wallet.
  bool get isOutbound => transferType.toUpperCase() == 'OUTBOUND_PAYMENT';

  /// Whether the transfer represents an incoming Lightning invoice.
  bool get isInboundInvoice => transferType.toUpperCase() == 'INBOUND_INVOICE';

  /// Whether its service category represents any supported incoming flow.
  bool get isInboundTransfer =>
      transferType.toUpperCase() == 'ADDRESS_ISSUE' ||
      transferType.toUpperCase() == 'ONRAMP_PURCHASE' ||
      transferType.toUpperCase() == 'INBOUND_INVOICE';

  /// Whether an on-chain transaction has evidence beyond an issued address.
  bool get hasDetectedOnchainTransaction =>
      blockchainTxid.trim().isNotEmpty || confirmations > 0;

  /// Projects this rail-specific record into the shared wallet activity model.
  ///
  /// Resolves status from service state and confirmations, prefers a stable
  /// blockchain/payment/provider identifier for the activity ID, and converts
  /// BTC amounts to satoshis. Missing timestamps fall back to the current time.
  Transaction toTransaction() {
    final normalizedStatus = status.toUpperCase();
    final txStatus = switch (normalizedStatus) {
      'COMPLETED' ||
      'SETTLED' ||
      'CONFIRMED' ||
      'PAID' =>
        TransactionStatus.confirmed,
      'CANCELLED' || 'EXPIRED' => TransactionStatus.cancelled,
      'FAILED' => TransactionStatus.failed,
      _ => confirmations > 0
          ? TransactionStatus.confirming
          : TransactionStatus.pending,
    };
    final transactionId = [
      blockchainTxid,
      paymentHash,
      externalReference,
      invoiceId,
      id,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => id);
    final displayAmountBtc =
        amountBtc.abs() > 0 ? amountBtc : expectedAmountBtc;
    return Transaction(
      id: transactionId,
      fromAddress: isOutbound ? walletName : '',
      toAddress: destination.isNotEmpty ? destination : walletName,
      amountSatoshis: (displayAmountBtc.abs() * 100000000).round(),
      feeSatoshis: (networkFeeBtc.abs() * 100000000).round(),
      status: txStatus,
      type: isOutbound ? TransactionType.withdrawal : TransactionType.deposit,
      confirmations: confirmations,
      timestamp: settledAt ?? detectedAt ?? createdAt ?? DateTime.now(),
      blockchainTxid: blockchainTxid.isNotEmpty ? blockchainTxid : null,
      externalReference:
          externalReference.isNotEmpty ? externalReference : null,
      invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
      lightningInvoice: invoiceData.isNotEmpty ? invoiceData : null,
      paymentHash: paymentHash.isNotEmpty ? paymentHash : null,
      externalTransferId: id,
      externalTransferStatus: status,
      externalTransferType: transferType,
      description: context,
      isInternal: false,
      isLightning: isLightning,
      rail: isLightning ? 'LIGHTNING' : (isOnchain ? 'ONCHAIN' : network),
      provider: provider.isNotEmpty ? provider : null,
    );
  }

  /// Parses the service payload, tolerating absent optional values and timestamps.
  ///
  /// Invalid or absent timestamps become `null`; absent status defaults to
  /// `PENDING`. This parser normalizes representation, not transfer validity.
  factory ExternalTransfer.fromJson(Map<String, dynamic> json) {
    return ExternalTransfer(
      id: json['id']?.toString() ?? '',
      network: json['network']?.toString() ?? '',
      transferType: json['transferType']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      provider: json['provider']?.toString() ?? '',
      walletName: json['walletName']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      amountBtc: (json['amountBtc'] as num?)?.toDouble() ?? 0,
      networkFeeBtc: (json['networkFeeBtc'] as num?)?.toDouble() ?? 0,
      platformFeeBtc: (json['platformFeeBtc'] as num?)?.toDouble() ?? 0,
      totalDebitedBtc: (json['totalDebitedBtc'] as num?)?.toDouble() ?? 0,
      externalReference: json['externalReference']?.toString() ?? '',
      invoiceId: json['invoiceId']?.toString() ?? '',
      blockchainTxid: json['blockchainTxid']?.toString() ?? '',
      paymentHash: json['paymentHash']?.toString() ?? '',
      invoiceData: json['invoiceData']?.toString() ?? '',
      expectedAmountBtc: (json['expectedAmountBtc'] as num?)?.toDouble() ?? 0,
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      detectedAt:
          DateTime.tryParse(json['detectedAt']?.toString() ?? '')?.toLocal(),
      settledAt:
          DateTime.tryParse(json['settledAt']?.toString() ?? '')?.toLocal(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
      context: json['context']?.toString() ?? '',
    );
  }

  @override

  /// Fields that determine equality for an external transfer.
  List<Object?> get props => [
        id,
        network,
        transferType,
        status,
        provider,
        walletName,
        destination,
        amountBtc,
        networkFeeBtc,
        platformFeeBtc,
        totalDebitedBtc,
        externalReference,
        invoiceId,
        blockchainTxid,
        paymentHash,
        invoiceData,
        expectedAmountBtc,
        confirmations,
        detectedAt,
        settledAt,
        createdAt,
        updatedAt,
        context,
      ];
}
