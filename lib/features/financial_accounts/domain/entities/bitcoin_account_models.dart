/// Client-side snapshot of an account and its custody/balance characteristics.
///
/// Balances are satoshis. Available, pending, locked, auto-held, and chain-
/// observed values remain distinct because they have different spendability
/// and reconciliation meanings.
class BitcoinAccount {
  /// Service account identifier.
  final String id;

  /// Account category returned by the account service.
  final String type;

  /// Custody model used to decide how the account may be operated.
  final String custody;

  /// Lifecycle state of the account.
  final String status;

  /// User-facing account name.
  final String label;

  /// Optional explanatory label for the wallet type.
  final String walletTypeDescription;

  /// Service risk classification associated with this account.
  final String riskTier;

  /// Associated card identifier for card-backed accounts.
  final String? cardId;

  /// Associated cold-wallet identifier for watch-only accounts.
  final String? coldWalletId;

  /// Ledger funds available for immediate spending, in satoshis.
  final int balanceAvailableSats;

  /// Incoming or otherwise pending ledger funds, in satoshis.
  final int balancePendingSats;

  /// Ledger funds locked by an active operation, in satoshis.
  final int balanceLockedSats;

  /// Ledger funds temporarily held by an automated risk control, in satoshis.
  final int balanceAutoHoldSats;

  /// Balance observed from the blockchain rather than the internal ledger.
  final int observedBalanceSats;

  /// Fingerprint identifying the extended public key, when applicable.
  final String? xpubFingerprint;

  /// Wallet derivation path associated with the public key.
  final String? derivationPath;

  /// Script type/policy used to derive the wallet's addresses.
  final String? scriptPolicy;

  /// Creates an account snapshot; omitted balances default to zero.
  const BitcoinAccount({
    required this.id,
    required this.type,
    required this.custody,
    required this.status,
    required this.label,
    this.walletTypeDescription = '',
    required this.riskTier,
    this.cardId,
    this.coldWalletId,
    this.balanceAvailableSats = 0,
    this.balancePendingSats = 0,
    this.balanceLockedSats = 0,
    this.balanceAutoHoldSats = 0,
    this.observedBalanceSats = 0,
    this.xpubFingerprint,
    this.derivationPath,
    this.scriptPolicy,
  });

  /// Whether the account is an internal or Kerosene-custodied account.
  bool get isInternal =>
      type == 'INTERNAL_CARD' ||
      custody == 'KEROSENE_CUSTODIAL' ||
      custody == 'INTERNAL';

  /// Whether the account is a hosted on-chain wallet.
  bool get isCustodialOnchain => custody == 'CUSTODIAL_ONCHAIN';

  /// Whether the account exposes public cold-wallet data without signing keys.
  bool get isWatchOnly =>
      type == 'WATCH_ONLY_COLD_WALLET' || custody == 'WATCH_ONLY';

  /// Whether the service reports the account as active.
  bool get isActive => status == 'ACTIVE';

  /// User-facing custody label derived from the account custody mode.
  String get custodyDisplayLabel {
    if (isWatchOnly) return 'Cold wallet';
    if (isCustodialOnchain) return 'Custodial on-chain';
    return 'Carteira global';
  }

  /// Primary UI balance (what the user can treat as "the" number for this account).
  /// Cold: chain-observed only. Custodial/internal: **available only** (not locked/holds).
  int get primarySats {
    if (isWatchOnly) return observedBalanceSats;
    return balanceAvailableSats;
  }

  /// Held ledger sats (pending + locked + auto-hold) — never fold into hero balance.
  int get heldSats {
    if (isWatchOnly) return 0;
    return balancePendingSats + balanceLockedSats + balanceAutoHoldSats;
  }

  /// Full ledger footprint (available + holds). Prefer [primarySats] for display.
  int get totalSats {
    if (isWatchOnly) return observedBalanceSats;
    return balanceAvailableSats + heldSats;
  }

  /// Blockchain-observed sats for cold/custodial on-chain reconciliation.
  int get chainObservedSats => observedBalanceSats;

  /// Parses the service account payload, accepting its legacy fingerprint alias.
  factory BitcoinAccount.fromJson(Map<String, dynamic> json) {
    return BitcoinAccount(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'INTERNAL_CARD',
      custody: json['custody'] as String? ?? 'KEROSENE_CUSTODIAL',
      status: json['status'] as String? ?? 'ACTIVE',
      label: json['label'] as String? ?? '',
      walletTypeDescription: json['walletTypeDescription'] as String? ?? '',
      riskTier: json['riskTier'] as String? ?? 'BRONZE',
      cardId: json['cardId'] as String?,
      coldWalletId: json['coldWalletId'] as String?,
      balanceAvailableSats: _intFromJson(json['balanceAvailableSats']),
      balancePendingSats: _intFromJson(json['balancePendingSats']),
      balanceLockedSats: _intFromJson(json['balanceLockedSats']),
      balanceAutoHoldSats: _intFromJson(json['balanceAutoHoldSats']),
      observedBalanceSats: _intFromJson(json['observedBalanceSats']),
      xpubFingerprint:
          (json['xpubFingerprint'] ?? json['fingerprint']) as String?,
      derivationPath: json['derivationPath'] as String?,
      scriptPolicy: json['scriptPolicy'] as String?,
    );
  }

  /// Serializes this account snapshot using the account API's JSON keys.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'custody': custody,
        'status': status,
        'label': label,
        'walletTypeDescription': walletTypeDescription,
        'riskTier': riskTier,
        'cardId': cardId,
        'coldWalletId': coldWalletId,
        'balanceAvailableSats': balanceAvailableSats,
        'balancePendingSats': balancePendingSats,
        'balanceLockedSats': balanceLockedSats,
        'balanceAutoHoldSats': balanceAutoHoldSats,
        'observedBalanceSats': observedBalanceSats,
        'xpubFingerprint': xpubFingerprint,
        'derivationPath': derivationPath,
        'scriptPolicy': scriptPolicy,
      };

  /// Converts integer/number/string JSON values to an integer, defaulting to zero.
  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Receive request/address details shown to the wallet owner.
class ReceivingRequestView {
  /// Service request identifier or deterministic KFE address key.
  final String id;

  /// Account that owns the receiving address.
  final String accountId;

  /// Plain Bitcoin address to receive funds.
  final String address;

  /// BIP-21 URI containing the address and optional amount.
  final String bip21;

  /// Server-side state of the receiving request.
  final String status;

  /// Requested amount in satoshis, if the request fixes an amount.
  final int? amountSats;

  /// Expiry instant or provider expiry text supplied by the service.
  final String expiry;

  /// Whether the address/request is intended for a single payment.
  final bool oneTime;

  /// Creation timestamp used for display and local ordering.
  final DateTime createdAt;

  /// Creates a receive request snapshot.
  const ReceivingRequestView({
    required this.id,
    required this.accountId,
    required this.address,
    required this.bip21,
    required this.status,
    required this.amountSats,
    required this.expiry,
    required this.oneTime,
    required this.createdAt,
  });

  /// Copies this value while optionally replacing its lifecycle status.
  ReceivingRequestView copyWith({String? status}) {
    return ReceivingRequestView(
      id: id,
      accountId: accountId,
      address: address,
      bip21: bip21,
      status: status ?? this.status,
      amountSats: amountSats,
      expiry: expiry,
      oneTime: oneTime,
      createdAt: createdAt,
    );
  }

  /// Parses a receive-request payload, using fallback account and date defaults.
  factory ReceivingRequestView.fromJson(
    Map<String, dynamic> json, {
    String? fallbackAccountId,
  }) {
    final createdAt = (json['createdAt'] ?? json['expiresAt'])?.toString();
    return ReceivingRequestView(
      id: json['id'] as String? ?? '',
      accountId:
          (json['accountId'] ?? json['cardId'] ?? fallbackAccountId ?? '')
              .toString(),
      address: json['address'] as String? ?? '',
      bip21: json['bip21'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      amountSats: _nullableIntFromJson(json['amountSats']),
      expiry: (json['expiry'] ?? json['expiresAt'] ?? '').toString(),
      oneTime: json['oneTime'] as bool? ?? true,
      createdAt: DateTime.tryParse(createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Adapts an active address response from KFE into a receive request view.
  ///
  /// Trims the address, derives a BIP-21 URI from an optional satoshi amount,
  /// and uses a deterministic ID so repeated observations identify the same
  /// account/address pair.
  factory ReceivingRequestView.fromKfeActiveAddress({
    required String accountId,
    required String address,
    int? amountSats,
    String expiry = '',
    bool oneTime = false,
    DateTime? createdAt,
  }) {
    final normalizedAddress = address.trim();
    final amountBtc = amountSats == null
        ? null
        : (amountSats / 100000000.0).toStringAsFixed(8);
    final bip21 = amountBtc == null
        ? 'bitcoin:$normalizedAddress'
        : 'bitcoin:$normalizedAddress?amount=$amountBtc';
    return ReceivingRequestView(
      id: 'kfe:$accountId:$normalizedAddress',
      accountId: accountId,
      address: normalizedAddress,
      bip21: bip21,
      status: 'ACTIVE',
      amountSats: amountSats,
      expiry: expiry,
      oneTime: oneTime,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Serializes the view into the client API's JSON field names.
  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'address': address,
        'bip21': bip21,
        'status': status,
        'amountSats': amountSats,
        'expiry': expiry,
        'oneTime': oneTime,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Parses a nullable satoshi amount without converting missing input to zero.
  static int? _nullableIntFromJson(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

/// Public view of one unspent transaction output controlled by a cold wallet.
class ColdWalletUtxoView {
  /// Service UTXO identifier, or a transaction/output fallback identifier.
  final String id;

  /// Transaction ID containing this output.
  final String txidRef;

  /// Zero-based output index within [txidRef].
  final int vout;

  /// Output value in satoshis.
  final int amountSats;

  /// Number of confirmations reported by the chain observer.
  final int confirmations;

  /// Service spend state, such as `UNSPENT`.
  final String status;

  /// Creates a cold-wallet UTXO snapshot.
  const ColdWalletUtxoView({
    required this.id,
    required this.txidRef,
    required this.vout,
    required this.amountSats,
    required this.confirmations,
    required this.status,
  });

  /// Whether the normalized service status marks this output unspent.
  bool get isSpendable => status.toUpperCase() == 'UNSPENT';

  /// Parses a UTXO payload and synthesizes its ID when the API omits one.
  factory ColdWalletUtxoView.fromJson(Map<String, dynamic> json) {
    final txid = (json['txidRef'] ?? json['txid'] ?? '').toString();
    final vout = _intFromJson(json['vout']);
    return ColdWalletUtxoView(
      id: (json['id'] ?? '$txid:$vout').toString(),
      txidRef: txid,
      vout: vout,
      amountSats: _intFromJson(json['amountSats'] ?? json['valueSats']),
      confirmations: _intFromJson(json['confirmations']),
      status: (json['status'] ?? 'UNSPENT').toString(),
    );
  }

  /// Serializes the UTXO fields using the service-facing JSON keys.
  Map<String, dynamic> toJson() => {
        'id': id,
        'txidRef': txidRef,
        'vout': vout,
        'amountSats': amountSats,
        'confirmations': confirmations,
        'status': status,
      };
}

/// State and unsigned payload for one cold-wallet PSBT signing workflow.
///
/// The unsigned PSBT is sensitive transaction material: callers should only
/// expose it to the intended signing flow and must not log it.
class PsbtWorkflowView {
  /// Workflow identifier used to query or advance this signing session.
  final String id;

  /// Cold wallet that owns the inputs being spent.
  final String coldWalletId;

  /// Unsigned PSBT that must be signed outside the online application.
  final String unsignedPsbt;

  /// Current service state of the signing workflow.
  final String status;

  /// Destination address encoded by the unsigned transaction.
  final String destinationAddress;

  /// Amount being sent, in satoshis.
  final int amountSats;

  /// Service-estimated transaction fee, in satoshis.
  final int estimatedFeeSats;

  /// Transaction ID returned after broadcast, if available.
  final String? broadcastTxid;

  /// Alternate service reference for the broadcast transaction.
  final String? broadcastTxidRef;

  /// Workflow expiry value supplied by the service.
  final String expiresAt;

  /// Workflow creation value supplied by the service.
  final String createdAt;

  /// Creates an immutable PSBT workflow snapshot.
  const PsbtWorkflowView({
    required this.id,
    required this.coldWalletId,
    required this.unsignedPsbt,
    required this.status,
    required this.destinationAddress,
    required this.amountSats,
    required this.estimatedFeeSats,
    this.broadcastTxid,
    this.broadcastTxidRef,
    required this.expiresAt,
    required this.createdAt,
  });

  /// Whether the workflow is still awaiting an external signature.
  bool get awaitsSignature {
    final normalized = status.toUpperCase();
    return normalized == 'CREATED' ||
        normalized == 'WAITING_EXTERNAL_SIGNATURE' ||
        normalized == 'UNSIGNED_CREATED' ||
        normalized == 'DRAFT';
  }

  /// Parses a workflow payload, accepting legacy aliases for ID and PSBT fields.
  factory PsbtWorkflowView.fromJson(Map<String, dynamic> json) {
    return PsbtWorkflowView(
      id: (json['workflowId'] ?? json['id'] ?? json['psbtHash'] ?? '')
          .toString(),
      coldWalletId: (json['coldWalletId'] ?? json['walletId'] ?? '').toString(),
      unsignedPsbt: (json['unsignedPsbt'] ?? json['psbt'] ?? '').toString(),
      status: (json['status'] ?? 'WAITING_EXTERNAL_SIGNATURE').toString(),
      destinationAddress: (json['destinationAddress'] ?? '').toString(),
      amountSats: _intFromJson(json['amountSats']),
      estimatedFeeSats: _intFromJson(
        json['estimatedFeeSats'] ?? json['feeSats'],
      ),
      broadcastTxid: json['broadcastTxid']?.toString(),
      broadcastTxidRef: json['broadcastTxidRef']?.toString(),
      expiresAt: (json['expiresAt'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  /// Serializes the workflow snapshot using client model field names.
  Map<String, dynamic> toJson() => {
        'id': id,
        'coldWalletId': coldWalletId,
        'unsignedPsbt': unsignedPsbt,
        'status': status,
        'destinationAddress': destinationAddress,
        'amountSats': amountSats,
        'estimatedFeeSats': estimatedFeeSats,
        'broadcastTxid': broadcastTxid,
        'broadcastTxidRef': broadcastTxidRef,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
      };
}

/// One sanitized tax-classification event exported by the service.
class TaxEventView {
  /// Event identifier.
  final String id;

  /// Service-defined event category.
  final String eventType;

  /// Asset code associated with the quantity, normally BTC.
  final String asset;

  /// Event quantity in satoshis.
  final int quantitySats;

  /// Tax classification assigned by the service or user workflow.
  final String classification;

  /// Sanitized source reference used to trace the originating activity.
  final String sourceRef;

  /// Creation timestamp returned by the service.
  final String createdAt;

  /// Related account, if known.
  final String? accountId;

  /// Related card, if known.
  final String? cardId;

  /// Related wallet, if known.
  final String? walletId;

  /// Retention/purge deadline supplied by the service, if applicable.
  final String? purgeAfter;

  /// Creates an immutable tax event snapshot.
  const TaxEventView({
    required this.id,
    required this.eventType,
    required this.asset,
    required this.quantitySats,
    required this.classification,
    required this.sourceRef,
    required this.createdAt,
    this.accountId,
    this.cardId,
    this.walletId,
    this.purgeAfter,
  });

  /// Parses a tax event payload, preserving absent relationships as `null`.
  factory TaxEventView.fromJson(Map<String, dynamic> json) {
    return TaxEventView(
      id: (json['id'] ?? '').toString(),
      eventType: (json['eventType'] ?? '').toString(),
      asset: (json['asset'] ?? 'BTC').toString(),
      quantitySats: _intFromJson(json['quantitySats']),
      classification: (json['classification'] ?? '').toString(),
      sourceRef: (json['sourceRef'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      accountId: json['accountId']?.toString(),
      cardId: json['cardId']?.toString(),
      walletId: json['walletId']?.toString(),
      purgeAfter: json['purgeAfter']?.toString(),
    );
  }

  /// Serializes the tax event using the export API's field names.
  Map<String, dynamic> toJson() => {
        'id': id,
        'eventType': eventType,
        'asset': asset,
        'quantitySats': quantitySats,
        'classification': classification,
        'sourceRef': sourceRef,
        'createdAt': createdAt,
        'accountId': accountId,
        'cardId': cardId,
        'walletId': walletId,
        'purgeAfter': purgeAfter,
      };
}

/// Complete export response containing metadata and sanitized tax events.
class TaxEventsExportView {
  /// Encoding format selected by the export endpoint.
  final String format;

  /// Suggested output filename for a downloaded export.
  final String filename;

  /// Educational notice that must accompany the exported data.
  final String educationalNotice;

  /// Pre-rendered export body when the server provides one.
  final String? content;

  /// Parsed event list; empty when the response does not include an event array.
  final List<TaxEventView> events;

  /// Creates an export snapshot with an empty event list by default.
  const TaxEventsExportView({
    required this.format,
    required this.filename,
    required this.educationalNotice,
    this.content,
    this.events = const [],
  });

  /// Parses export metadata and converts map entries into [TaxEventView] values.
  factory TaxEventsExportView.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    return TaxEventsExportView(
      format: (json['format'] ?? 'json').toString(),
      filename: (json['filename'] ?? 'kerosene-tax-events.json').toString(),
      educationalNotice: (json['educationalNotice'] ?? '').toString(),
      content: json['content']?.toString(),
      events: rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map((item) => TaxEventView.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  /// Serializes export metadata and its events into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'format': format,
        'filename': filename,
        'educationalNotice': educationalNotice,
        'content': content,
        'events': events.map((event) => event.toJson()).toList(),
      };
}

/// Converts supported JSON numeric representations to an integer or zero.
int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
