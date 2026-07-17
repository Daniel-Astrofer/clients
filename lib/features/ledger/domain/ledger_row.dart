/// Projection row for LocalLedgerSync (design: docs/frontend/LOCAL_LEDGER_SYNC.md).
///
/// Pure data — no Flutter dependencies. UI continues to use [Transaction];
/// adapters map to/from this model for merge rules.
enum LedgerDirection { inbound, outbound, internal }

enum LedgerRail { onchain, lightning, internal }

enum LedgerStatus {
  pending,
  confirming,
  confirmed,
  failed,
  cancelled,
  reconciling,
}

enum LedgerSource { remote, statement, local }

class LedgerRow {
  final String id;
  final LedgerDirection direction;
  final LedgerRail rail;
  final LedgerStatus status;
  final int confirmations;
  final int amountSats;
  final int feeSats;
  final int serviceFeeSats;
  final String? sourceWalletId;
  final String? destinationWalletId;
  final String? blockchainTxid;
  final String? externalReference;
  final String? provider;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool localOnly;
  final bool tombstone;
  final LedgerSource source;

  const LedgerRow({
    required this.id,
    required this.direction,
    required this.rail,
    required this.status,
    required this.confirmations,
    required this.amountSats,
    this.feeSats = 0,
    this.serviceFeeSats = 0,
    this.sourceWalletId,
    this.destinationWalletId,
    this.blockchainTxid,
    this.externalReference,
    this.provider,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
    this.localOnly = false,
    this.tombstone = false,
    this.source = LedgerSource.remote,
  });

  LedgerRow copyWith({
    String? id,
    LedgerDirection? direction,
    LedgerRail? rail,
    LedgerStatus? status,
    int? confirmations,
    int? amountSats,
    int? feeSats,
    int? serviceFeeSats,
    String? sourceWalletId,
    String? destinationWalletId,
    String? blockchainTxid,
    String? externalReference,
    String? provider,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? localOnly,
    bool? tombstone,
    LedgerSource? source,
  }) {
    return LedgerRow(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      rail: rail ?? this.rail,
      status: status ?? this.status,
      confirmations: confirmations ?? this.confirmations,
      amountSats: amountSats ?? this.amountSats,
      feeSats: feeSats ?? this.feeSats,
      serviceFeeSats: serviceFeeSats ?? this.serviceFeeSats,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      blockchainTxid: blockchainTxid ?? this.blockchainTxid,
      externalReference: externalReference ?? this.externalReference,
      provider: provider ?? this.provider,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localOnly: localOnly ?? this.localOnly,
      tombstone: tombstone ?? this.tombstone,
      source: source ?? this.source,
    );
  }
}

class BalanceSnapshot {
  final String walletId;
  final String kind;
  final String label;
  final int availableSats;
  final int observedSats;
  final int pendingSats;
  final int lockedSats;
  final DateTime updatedAt;

  const BalanceSnapshot({
    required this.walletId,
    required this.kind,
    required this.label,
    required this.availableSats,
    required this.observedSats,
    this.pendingSats = 0,
    this.lockedSats = 0,
    required this.updatedAt,
  });

  /// Primary amount for UI by custody kind (design §4.3).
  int get primaryDisplaySats {
    final k = kind.toUpperCase();
    if (k == 'WATCH_ONLY') return observedSats;
    return availableSats;
  }

  bool get showObservedSubtitle {
    final k = kind.toUpperCase();
    return k == 'CUSTODIAL_ONCHAIN' && observedSats != availableSats;
  }
}
