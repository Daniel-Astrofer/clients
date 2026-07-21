import 'package:equatable/equatable.dart';

/// Entidade Transaction - Transação Bitcoin
/// Representa uma transação na blockchain ou pendente
final class Transaction extends Equatable {
  /// ID da transação (txid - hash SHA256)
  final String id;

  /// Endereço de origem
  final String fromAddress;

  /// Endereço de destino
  final String toAddress;

  /// Carteira relacionada ao lançamento quando a API informa.
  final String? walletId;

  /// Carteira de origem quando a API informa.
  final String? sourceWalletId;

  /// Carteira de destino quando a API informa.
  final String? destinationWalletId;

  /// Nome ou identificador seguro do remetente quando a API fornece.
  final String? senderDisplayName;

  /// Nome ou identificador seguro do destinatário quando a API fornece.
  final String? receiverDisplayName;

  /// Label da carteira de perspectiva (API).
  final String? walletLabel;

  /// Label da carteira de origem (API).
  final String? sourceWalletLabel;

  /// Label da carteira de destino (API).
  final String? destinationWalletLabel;

  /// Contraparte resolvida no servidor (API) — preferir no card.
  final String? counterpartyLabel;

  /// Valor em satoshis
  final int amountSatoshis;

  /// Taxa de rede em satoshis
  final int feeSatoshis;

  /// Taxa de serviço da plataforma (Kerosene) em satoshis.
  final int serviceFeeSatoshis;

  /// Status da transação
  final TransactionStatus status;

  /// Tipo de transação
  final TransactionType type;

  /// Número de confirmações na blockchain
  final int confirmations;

  /// Timestamp da transação
  final DateTime timestamp;

  /// Last server-side update (merge clock). Falls back to [timestamp] when absent.
  final DateTime? updatedAt;

  /// Hash do bloco (null se pendente)
  final String? blockHash;

  /// Altura do bloco (null se pendente)
  final int? blockHeight;

  /// TXID on-chain quando a entrada do ledger referencia uma transação externa.
  final String? blockchainTxid;

  /// Referência externa do provedor ou invoice.
  final String? externalReference;

  /// Identificador do invoice no provedor.
  final String? invoiceId;

  /// BOLT11 ou payload do invoice Lightning.
  final String? lightningInvoice;

  /// Payment hash Lightning.
  final String? paymentHash;

  /// UUID interno do ExternalTransfer, usado para ações self-service.
  final String? externalTransferId;

  /// Status bruto do ExternalTransfer, quando a transação veio desse fluxo.
  final String? externalTransferStatus;

  /// Tipo bruto do ExternalTransfer, por exemplo INBOUND_INVOICE.
  final String? externalTransferType;

  /// Descrição/nota da transação
  final String? description;

  /// Indica se é uma transação interna (entre usuários da plataforma)
  final bool isInternal;

  /// Indica se é uma transação Lightning
  final bool isLightning;

  /// Rail bruto da API KFE: INTERNAL | ONCHAIN | LIGHTNING (quando presente).
  final String? rail;

  /// Provider bruto da API KFE (ex.: COLD_EXTERNAL_SPEND, BITCOIN_CORE, PAYMENT_LINK).
  final String? provider;

  /// Stable failure code from KFE (safe for localized mapping). Never a stack.
  final String? failureCode;

  /// From KFE detail/list: client may show Cancel when true.
  final bool cancellable;

  /// `PAYMENT_REQUEST` | `TRANSACTION` | null.
  final String? cancelTarget;

  final String? paymentRequestId;
  final String? paymentRequestPublicId;
  final String? paymentRequestStatus;

  /// Indica se a transação possui taxa de rede exibível.
  final bool hasNetworkFee;

  /// Valor fiat congelado no momento da execução, em USD.
  final double? displayAmountUsd;

  /// Valor fiat congelado no momento da execução, em EUR.
  final double? displayAmountEur;

  /// Valor fiat congelado no momento da execução, em BRL.
  final double? displayAmountBrl;

  /// Cotação BTC/USD congelada no momento da execução.
  final double? displayBtcUsd;

  /// Cotação BTC/EUR congelada no momento da execução.
  final double? displayBtcEur;

  /// Cotação BTC/BRL congelada no momento da execução.
  final double? displayBtcBrl;

  const Transaction({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    this.walletId,
    this.sourceWalletId,
    this.destinationWalletId,
    this.senderDisplayName,
    this.receiverDisplayName,
    this.walletLabel,
    this.sourceWalletLabel,
    this.destinationWalletLabel,
    this.counterpartyLabel,
    required this.amountSatoshis,
    required this.feeSatoshis,
    this.serviceFeeSatoshis = 0,
    required this.status,
    required this.type,
    required this.confirmations,
    required this.timestamp,
    this.updatedAt,
    this.blockHash,
    this.blockHeight,
    this.blockchainTxid,
    this.externalReference,
    this.invoiceId,
    this.lightningInvoice,
    this.paymentHash,
    this.externalTransferId,
    this.externalTransferStatus,
    this.externalTransferType,
    this.description,
    this.isInternal = false,
    this.isLightning = false,
    this.rail,
    this.provider,
    this.failureCode,
    this.cancellable = false,
    this.cancelTarget,
    this.paymentRequestId,
    this.paymentRequestPublicId,
    this.paymentRequestStatus,
    this.hasNetworkFee = false,
    this.displayAmountUsd,
    this.displayAmountEur,
    this.displayAmountBrl,
    this.displayBtcUsd,
    this.displayBtcEur,
    this.displayBtcBrl,
  });

  /// Merge / freshness clock (server updatedAt when known).
  DateTime get effectiveUpdatedAt => updatedAt ?? timestamp;

  /// Valor total (amount + fee)
  int get totalSatoshis => amountSatoshis + feeSatoshis;

  /// Debit compact amount: principal + network fee + service fee when present.
  int get signedDisplaySatoshis {
    if (!isDebit) return amountSatoshis;
    var total = amountSatoshis;
    if (showsNetworkFee) total += feeSatoshis;
    if (showsServiceFee) total += serviceFeeSatoshis;
    return total;
  }

  double get signedDisplayAmountBTC =>
      isDebit ? -(signedDisplaySatoshis / 100000000.0) : amountBTC;

  /// Valor em BTC
  double get amountBTC => amountSatoshis / 100000000.0;

  /// Taxa em BTC
  double get feeBTC => feeSatoshis / 100000000.0;

  /// Taxa de serviço em BTC
  double get serviceFeeBTC => serviceFeeSatoshis / 100000000.0;

  bool get hasServiceFee => serviceFeeSatoshis > 0;

  /// Movimentos que reduzem o saldo do usuario.
  bool get isDebit =>
      type == TransactionType.send ||
      type == TransactionType.withdrawal ||
      type == TransactionType.fee;

  /// Movimentos que aumentam o saldo do usuario.
  bool get isCredit =>
      type == TransactionType.receive || type == TransactionType.deposit;

  /// Valor em BTC com sinal do ponto de vista do usuario atual.
  double get signedAmountBTC => isDebit ? -amountBTC : amountBTC;

  /// Lightning by flag, rail, or payment-hash / bolt11 (cache may omit flags).
  bool get isLightningEffective {
    if (isLightning) return true;
    final r = (rail ?? '').trim().toUpperCase();
    if (r == 'LIGHTNING') return true;
    if ((paymentHash ?? '').trim().isNotEmpty) return true;
    if ((lightningInvoice ?? '').trim().isNotEmpty) return true;
    return false;
  }

  /// Ledger-internal transfer (Kerosene → Kerosene). Not a chain object.
  bool get isLedgerInternal => isInternal && !isLightningEffective;

  /// Bitcoin on-chain movement (external deposit/withdraw/cold observation).
  bool get isOnChain => !isInternal && !isLightningEffective;

  /// Normalized rail string (INTERNAL / ONCHAIN / LIGHTNING / empty).
  String get normalizedRail {
    final raw = (rail ?? '').trim().toUpperCase();
    if (raw.isNotEmpty) return raw;
    if (isLightningEffective) return 'LIGHTNING';
    if (isInternal) return 'INTERNAL';
    if (isOnChain) return 'ONCHAIN';
    return '';
  }

  /// Provider uppercased for classification (cold observer, payment link, etc.).
  String get normalizedProvider => (provider ?? '').trim().toUpperCase();

  /// True when KFE tagged this as cold external observe/spend/PSBT.
  bool get isColdProvider {
    final p = normalizedProvider;
    if (p.isEmpty) return false;
    return p == 'COLD_OBSERVE' ||
        p == 'COLD_SPEND' ||
        p.contains('COLD_EXTERNAL') ||
        p.contains('COLD_OBSERVER') ||
        p.contains('COLD_OBSERVE') ||
        p.contains('COLD_PSBT') ||
        p.contains('COLD_SPEND') ||
        p.contains('WATCH_ONLY') ||
        p == 'COLD';
  }

  /// Payment-link product flow (id pl_* or provider/description markers).
  bool get isPaymentLink {
    if (id.startsWith('pl_')) return true;
    final p = normalizedProvider;
    if (p.contains('PAYMENT_LINK') || p.contains('PAYLINK')) return true;
    final d = (description ?? '').toLowerCase();
    return d.contains('link de pagamento') ||
        d.contains('payment link') ||
        d.contains('pagamento por link');
  }

  /// Payment link settled on internal ledger (not on-chain address).
  bool get isPaymentLinkInternal =>
      isPaymentLink && (isInternal || normalizedRail == 'INTERNAL');

  /// Payment link settled via on-chain deposit address.
  bool get isPaymentLinkOnchain =>
      isPaymentLink && !isPaymentLinkInternal && !isLightningEffective;

  /// UI: blockchain confirmation progress (rings / N/6).
  /// Internal ledger and Lightning settle by protocol status, never block confs.
  bool get showsOnchainConfirmations {
    if (isLightningEffective || isInternal) return false;
    if (!isOnChain) return false;
    final txid = blockchainTxid?.trim() ?? '';
    if (txid.isNotEmpty) return true;
    return type == TransactionType.deposit ||
        type == TransactionType.withdrawal ||
        type == TransactionType.send ||
        type == TransactionType.receive;
  }

  /// Target rings for on-chain progress UI (always 0→6, never fake full ring at 0).
  int get onchainConfirmationTarget => 6;

  /// True when backend marked settled but chain confs are still 0 (mempool).
  bool get isMempoolSettled =>
      isOnChain &&
      status == TransactionStatus.confirmed &&
      confirmations <= 0;

  /// Backend still exposes the row, but it never got a confirmation within 24h.
  /// UI should leave the "pending" path and surface "não confirmada".
  bool get isUnconfirmedExpired {
    if (!isOnChain) return false;
    if (status == TransactionStatus.confirmed ||
        status == TransactionStatus.failed ||
        status == TransactionStatus.cancelled ||
        status == TransactionStatus.reconciling) {
      return false;
    }
    // Only pure zero-conf waits expire; any backend conf keeps it alive.
    if (confirmations > 0) return false;
    return DateTime.now().toUtc().difference(timestamp.toUtc()) >
        const Duration(hours: 24);
  }

  /// Effective status for home/statement UI (applies 24h unconfirmed rule).
  /// Does **not** map reconciliation to failed — funds may still be reserved.
  /// User-cancelled KFE txs use FAILED + failureCode USER_CANCELLED → cancelled.
  TransactionStatus get displayStatus {
    if (_isUserCancelledFailure) {
      return TransactionStatus.cancelled;
    }
    if (status == TransactionStatus.reconciling) {
      return TransactionStatus.reconciling;
    }
    if (isUnconfirmedExpired) return TransactionStatus.failed;
    return status;
  }

  bool get _isUserCancelledFailure {
    final code = (failureCode ?? '').trim().toUpperCase();
    return code == 'USER_CANCELLED' || code == 'USER_CANCELED';
  }

  /// UI: miner / routing network fee row.
  bool get showsNetworkFee {
    if (isLedgerInternal) return false;
    return hasNetworkFee || feeSatoshis > 0;
  }

  /// UI: platform service fee row (hide when zero).
  bool get showsServiceFee => hasServiceFee;

  /// Verifica se a transação está confirmada (status final ou confs suficientes).
  bool get isConfirmed =>
      status == TransactionStatus.confirmed ||
      (showsOnchainConfirmations &&
          confirmations >= onchainConfirmationTarget);

  /// Verifica se a transação está pendente
  bool get isPending => status == TransactionStatus.pending;

  /// Cancelled / user-dismissed (includes KFE USER_CANCELLED failures).
  bool get isCancelled =>
      status == TransactionStatus.cancelled ||
      displayStatus == TransactionStatus.cancelled;

  /// Eligible to move to Arquivadas after the user opens the detail.
  bool get isArchiveEligible => isCancelled;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'walletId': walletId,
      'sourceWalletId': sourceWalletId,
      'destinationWalletId': destinationWalletId,
      'senderDisplayName': senderDisplayName,
      'receiverDisplayName': receiverDisplayName,
      'walletLabel': walletLabel,
      'sourceWalletLabel': sourceWalletLabel,
      'destinationWalletLabel': destinationWalletLabel,
      'counterpartyLabel': counterpartyLabel,
      'amountSatoshis': amountSatoshis,
      'feeSatoshis': feeSatoshis,
      'serviceFeeSatoshis': serviceFeeSatoshis,
      'status': status.name,
      'type': type.name,
      'confirmations': confirmations,
      'timestamp': timestamp.toIso8601String(),
      'updatedAt': (updatedAt ?? timestamp).toIso8601String(),
      'blockHash': blockHash,
      'blockHeight': blockHeight,
      'blockchainTxid': blockchainTxid,
      'externalReference': externalReference,
      'invoiceId': invoiceId,
      'lightningInvoice': lightningInvoice,
      'paymentHash': paymentHash,
      'externalTransferId': externalTransferId,
      'externalTransferStatus': externalTransferStatus,
      'externalTransferType': externalTransferType,
      'description': description,
      'isInternal': isInternal,
      'isLightning': isLightning,
      'rail': rail,
      'provider': provider,
      'failureCode': failureCode,
      'cancellable': cancellable,
      'cancelTarget': cancelTarget,
      'paymentRequestId': paymentRequestId,
      'paymentRequestPublicId': paymentRequestPublicId,
      'paymentRequestStatus': paymentRequestStatus,
      'hasNetworkFee': hasNetworkFee,
      'displayAmountUsd': displayAmountUsd,
      'displayAmountEur': displayAmountEur,
      'displayAmountBrl': displayAmountBrl,
      'displayBtcUsd': displayBtcUsd,
      'displayBtcEur': displayBtcEur,
      'displayBtcBrl': displayBtcBrl,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('grossAmountSats') ||
        json.containsKey('receiverAmountSats') ||
        json.containsKey('totalDebitSats') ||
        json.containsKey('amountSats') ||
        json.containsKey('amountSatoshis') ||
        json.containsKey('netAmountSats') ||
        json.containsKey('creditedSats') ||
        (json.containsKey('direction') && json.containsKey('rail'))) {
      return _fromKfeJson(json);
    }

    // If it's from local storage (newly added format)
    if (json.containsKey('status') &&
        json['status'] is String &&
        json.containsKey('amountSatoshis')) {
      return Transaction(
        id: json['id'],
        fromAddress: json['fromAddress'],
        toAddress: json['toAddress'],
        walletId: json['walletId']?.toString(),
        sourceWalletId: json['sourceWalletId']?.toString(),
        destinationWalletId: json['destinationWalletId']?.toString(),
        senderDisplayName: json['senderDisplayName']?.toString(),
        receiverDisplayName: json['receiverDisplayName']?.toString(),
        walletLabel: json['walletLabel']?.toString(),
        sourceWalletLabel: json['sourceWalletLabel']?.toString(),
        destinationWalletLabel: json['destinationWalletLabel']?.toString(),
        counterpartyLabel: json['counterpartyLabel']?.toString(),
        amountSatoshis: json['amountSatoshis'] is int
            ? json['amountSatoshis']
            : (json['amountSatoshis'] as num).toInt(),
        feeSatoshis: json['feeSatoshis'] is int
            ? json['feeSatoshis']
            : (json['feeSatoshis'] as num).toInt(),
        serviceFeeSatoshis: json['serviceFeeSatoshis'] is int
            ? json['serviceFeeSatoshis'] as int
            : ((json['serviceFeeSatoshis'] as num?)?.toInt() ??
                (json['keroseneFeeSats'] as num?)?.toInt() ??
                0),
        status: TransactionStatus.values.firstWhere(
          (e) => e.name == json['status'],
        ),
        type: TransactionType.values.firstWhere((e) => e.name == json['type']),
        confirmations: () {
          final lightning = json['isLightning'] == true ||
              (json['rail']?.toString().toUpperCase() == 'LIGHTNING');
          final internal = json['isInternal'] == true ||
              (json['rail']?.toString().toUpperCase() == 'INTERNAL');
          if (lightning || internal) return 0;
          final raw = json['confirmations'];
          if (raw is int) return raw;
          if (raw is num) return raw.toInt();
          return int.tryParse(raw?.toString() ?? '') ?? 0;
        }(),
        timestamp: _parseDateTime(json['timestamp'] ?? json['createdAt']) ??
            DateTime.now(),
        updatedAt: _parseDateTime(json['updatedAt']),
        blockHash: json['blockHash'],
        blockHeight: json['blockHeight'],
        blockchainTxid: json['blockchainTxid']?.toString(),
        externalReference: json['externalReference']?.toString(),
        invoiceId: json['invoiceId']?.toString(),
        lightningInvoice: json['lightningInvoice']?.toString(),
        paymentHash: json['paymentHash']?.toString(),
        externalTransferId: json['externalTransferId']?.toString(),
        externalTransferStatus: json['externalTransferStatus']?.toString(),
        externalTransferType: json['externalTransferType']?.toString(),
        description: json['description'],
        isInternal: json['isInternal'] ?? false,
        isLightning: json['isLightning'] ?? false,
        rail: json['rail']?.toString(),
        provider: json['provider']?.toString(),
        // Never persist raw failureMessage (may contain internal detail).
        failureCode: json['failureCode']?.toString(),
        cancellable: json['cancellable'] == true,
        cancelTarget: json['cancelTarget']?.toString(),
        paymentRequestId: json['paymentRequestId']?.toString(),
        paymentRequestPublicId: json['paymentRequestPublicId']?.toString(),
        paymentRequestStatus: json['paymentRequestStatus']?.toString(),
        hasNetworkFee: json['hasNetworkFee'] == true,
        displayAmountUsd: _parseNonZeroDouble(_firstJsonValue(json, const [
          'displayAmountUsd',
          'historicalAmountUsd',
          'amountUsd',
        ])),
        displayAmountEur: _parseNonZeroDouble(_firstJsonValue(json, const [
          'displayAmountEur',
          'historicalAmountEur',
          'amountEur',
        ])),
        displayAmountBrl: _parseNonZeroDouble(_firstJsonValue(json, const [
          'displayAmountBrl',
          'historicalAmountBrl',
          'amountBrl',
        ])),
        displayBtcUsd: _parsePositiveDouble(_firstJsonValue(json, const [
          'displayBtcUsd',
          'btcUsdSnapshot',
          'btcUsd',
        ])),
        displayBtcEur: _parsePositiveDouble(_firstJsonValue(json, const [
          'displayBtcEur',
          'btcEurSnapshot',
          'btcEur',
        ])),
        displayBtcBrl: _parsePositiveDouble(_firstJsonValue(json, const [
          'displayBtcBrl',
          'btcBrlSnapshot',
          'btcBrl',
        ])),
      );
    }

    // LedgerSyncEventDTO / sanitized ephemeral API payload format
    final amountVal = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final networkFee = (json['networkFee'] as num?)?.toDouble() ?? 0.0;
    final currentUserId = _parseInt(
      json['currentUserId'] ??
          json['currentUserID'] ??
          json['userId'] ??
          json['authenticatedUserId'],
    );
    final senderUserId = _parseInt(
      json['senderUserId'] ??
          json['senderUserID'] ??
          json['payerUserId'] ??
          json['fromUserId'],
    );
    final receiverUserId = _parseInt(
      json['receiverUserId'] ??
          json['receiverUserID'] ??
          json['payeeUserId'] ??
          json['toUserId'],
    );

    final senderField = [
      json['senderIdentifier'],
      json['sender'],
      json['from'],
      json['fromAddress'],
    ]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

    final receiverField = [
      json['receiverIdentifier'],
      json['receiver'],
      json['to'],
      json['toAddress'],
    ]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
    final currentUserIdentifier = [
      json['currentUsername'],
      json['currentUserName'],
      json['currentWalletName'],
      json['currentWalletAddress'],
    ]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
    final rawWalletId = json['walletId']?.toString();
    final rawSourceWalletId = json['sourceWalletId']?.toString();
    final rawDestinationWalletId = json['destinationWalletId']?.toString();

    final typeField =
        (json['transactionType'] ?? json['type'])?.toString().toUpperCase() ??
            '';
    final transferTypeField =
        (json['externalTransferType'] ?? json['transferType'])
                ?.toString()
                .toUpperCase() ??
            '';
    final directionField = (json['direction'] ??
                json['ledgerDirection'] ??
                json['movement'] ??
                json['operation'] ??
                json['entryType'] ??
                json['side'] ??
                json['amountDirection'])
            ?.toString()
            .toUpperCase() ??
        '';
    final contextField =
        (json['context'] ?? json['description'])?.toString().toUpperCase() ??
            '';
    final confirmations =
        _parseInt(json['confirmations']) ?? _parseInt(json['nonce']) ?? 0;
    final txType = _resolveType(
      typeField: typeField,
      transferTypeField: transferTypeField,
      contextField: contextField,
      directionField: directionField,
      amountVal: amountVal,
      currentUserId: currentUserId,
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      currentUserIdentifier: currentUserIdentifier,
      senderIdentifier: senderField,
      receiverIdentifier: receiverField,
    );
    final isInternalLegacy = typeField == 'INTERNAL' ||
        typeField == 'TRANSFER' ||
        typeField == 'TRANSACTION_SEND' ||
        typeField == 'TRANSACTION_RECEIVE' ||
        json['context'] == 'transfer' ||
        (json['description']?.toString().toLowerCase().contains('transfer') ??
            false);
    final isLightningLegacy = typeField.contains('LIGHTNING') ||
        (json['description']?.toString().toUpperCase().contains(
                  'LIGHTNING',
                ) ??
            false) ||
        (json['context']?.toString().toUpperCase().contains('LIGHTNING') ??
            false);
    final txStatus = _resolveStatus(
      rawStatus: json['status']?.toString(),
      confirmations: isInternalLegacy || isLightningLegacy ? 0 : confirmations,
    );
    final createdAt = _parseDateTime(json['createdAt'] ?? json['timestamp']);
    final networkFeeSats = isInternalLegacy
        ? 0
        : (networkFee.abs() * 100000000).round();

    return Transaction(
      id: (json['id'] ?? json['blockchainTxid'] ?? '').toString(),
      fromAddress: senderField ??
          (txType == TransactionType.send ||
                  txType == TransactionType.withdrawal
              ? 'Minha carteira'
              : 'Rede Bitcoin'),
      toAddress: receiverField ??
          (txType == TransactionType.send ||
                  txType == TransactionType.withdrawal
              ? 'Rede Bitcoin'
              : 'Minha carteira'),
      walletId: rawWalletId,
      sourceWalletId: rawSourceWalletId,
      destinationWalletId: rawDestinationWalletId,
      amountSatoshis: (amountVal.abs() * 100000000).round(),
      feeSatoshis: networkFeeSats,
      serviceFeeSatoshis: _parseServiceFeeSats(json, networkFeeBtc: networkFee),
      status: txStatus,
      type: txType,
      confirmations:
          isInternalLegacy || isLightningLegacy ? 0 : confirmations,
      timestamp: createdAt ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? createdAt,
      description:
          json['context']?.toString() ?? json['description']?.toString(),
      blockchainTxid:
          isInternalLegacy ? null : json['blockchainTxid']?.toString(),
      externalReference: json['externalReference']?.toString(),
      invoiceId: json['invoiceId']?.toString(),
      lightningInvoice: json['lightningInvoice']?.toString(),
      paymentHash: json['paymentHash']?.toString(),
      externalTransferId: json['externalTransferId']?.toString() ??
          json['externalTransferID']?.toString(),
      externalTransferStatus: json['externalTransferStatus']?.toString(),
      externalTransferType: json['externalTransferType']?.toString() ??
          json['transferType']?.toString(),
      isInternal: isInternalLegacy,
      isLightning: isLightningLegacy,
      rail: json['rail']?.toString() ??
          (isLightningLegacy
              ? 'LIGHTNING'
              : isInternalLegacy
                  ? 'INTERNAL'
                  : null),
      provider: json['provider']?.toString(),
      hasNetworkFee: networkFeeSats > 0,
      displayAmountUsd: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountUsd',
        'historicalAmountUsd',
        'amountUsd',
      ])),
      displayAmountEur: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountEur',
        'historicalAmountEur',
        'amountEur',
      ])),
      displayAmountBrl: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountBrl',
        'historicalAmountBrl',
        'amountBrl',
      ])),
      displayBtcUsd: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcUsd',
        'btcUsdSnapshot',
        'btcUsd',
      ])),
      displayBtcEur: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcEur',
        'btcEurSnapshot',
        'btcEur',
      ])),
      displayBtcBrl: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcBrl',
        'btcBrlSnapshot',
        'btcBrl',
      ])),
    );
  }

  static Transaction _fromKfeJson(Map<String, dynamic> json) {
    final rail = json['rail']?.toString().toUpperCase() ?? '';
    final direction = json['direction']?.toString().toUpperCase() ?? '';
    final walletId = json['walletId']?.toString();
    final sourceWalletId = json['sourceWalletId']?.toString();
    final destinationWalletId = json['destinationWalletId']?.toString();
    final externalReference = json['externalReference']?.toString();
    final networkFeeSats = _parseInt(json['networkFeeSats']) ?? 0;
    final serviceFeeSats = _parseInt(json['keroseneFeeSats']) ??
        _parseInt(json['serviceFeeSats']) ??
        _parseInt(json['platformFeeSats']) ??
        0;
    final totalDebitSats = _parseInt(json['totalDebitSats']) ?? 0;
    // Prefer explicit principal fields. Treat 0 as missing so ?? can fall through
    // (Dart: `0 ?? x` is 0 — that was zeroing on-chain history amounts).
    final grossAmountSats = _parsePositiveInt(json['grossAmountSats']) ??
        _parsePositiveInt(json['amountSats']) ??
        _parsePositiveInt(json['amountSatoshis']) ??
        _parsePositiveInt(json['netAmountSats']) ??
        _parsePositiveInt(json['creditedSats']) ??
        _parsePositiveInt(json['receivedSatoshis']) ??
        _parsePositiveInt(json['receivedAmountSats']) ??
        _parsePositiveInt(json['valueSats']) ??
        () {
          if (totalDebitSats > 0) {
            final principal =
                totalDebitSats - networkFeeSats.abs() - serviceFeeSats.abs();
            return principal > 0 ? principal : totalDebitSats;
          }
          return null;
        }() ??
        _parseBtcToSats(json['amountBtc'] ?? json['amount_btc'] ?? json['amount']);
    final rawReceiverSats = _parseInt(json['receiverAmountSats']);
    final receiverAmountSats = (rawReceiverSats != null && rawReceiverSats > 0)
        ? rawReceiverSats
        : (grossAmountSats != 0 ? grossAmountSats : (rawReceiverSats ?? 0));
    final confirmations = _parseInt(json['confirmations']) ?? 0;
    final isLightning = rail == 'LIGHTNING';
    final isInternal = rail == 'INTERNAL' || direction == 'INTERNAL';
    final isCredit = direction == 'INBOUND' ||
        (isInternal &&
            walletId != null &&
            destinationWalletId != null &&
            walletId == destinationWalletId);
    final txType = isCredit
        ? TransactionType.receive
        : isInternal
            ? TransactionType.send
            : direction == 'INBOUND'
                ? TransactionType.deposit
                : TransactionType.withdrawal;
    final status = _resolveKfeStatus(
      json['status']?.toString(),
      confirmations: confirmations,
      isInternal: isInternal,
      isLightning: isLightning,
    );
    final blockchainTxid = json['blockchainTxid']?.toString();
    // Prefer stable KFE UUID so cold observer/spend rows never collide when
    // multiple history items share a funding txid or one lacks a spend txid.
    final id = [
      json['id']?.toString(),
      json['transactionId']?.toString(),
      blockchainTxid,
    ].firstWhere(
      (value) => value != null && value.trim().isNotEmpty,
      orElse: () => '',
    )!;

    // Internal ledger never has miner fees; ignore accidental non-zero noise.
    final effectiveNetworkFee =
        isInternal ? 0 : networkFeeSats.abs();
    final effectiveConfs = isInternal || isLightning ? 0 : confirmations;

    final memo = json['memo']?.toString();
    final provider = json['provider']?.toString() ?? '';
    final providerUpper = provider.toUpperCase();
    final isColdExternal = providerUpper.contains('COLD_EXTERNAL') ||
        providerUpper.contains('COLD_OBSERVER') ||
        providerUpper.contains('COLD_PSBT') ||
        providerUpper.contains('WATCH_ONLY');
    final isPaymentLinkProvider = providerUpper.contains('PAYMENT_LINK') ||
        providerUpper.contains('PAYLINK') ||
        (memo ?? '').toLowerCase().contains('link de pagamento') ||
        (memo ?? '').toLowerCase().contains('payment link');
    // Parties:
    // - Debit (send): from = our source wallet; to = on-chain dest (externalReference).
    // - Credit (receive): from = external network (NOT our receive address in externalReference);
    //   to = destination wallet. Cold inbound stores our address in externalReference.
    final resolvedTo = isCredit
        ? (destinationWalletId ?? walletId ?? '')
        : (externalReference?.trim().isNotEmpty == true
            ? externalReference!.trim()
            : (destinationWalletId ?? blockchainTxid ?? ''));
    final resolvedFrom = isCredit
        ? (isInternal
            ? (sourceWalletId ?? 'Kerosene')
            : (sourceWalletId ??
                (isColdExternal ? 'Rede Bitcoin (cold)' : 'Rede Bitcoin')))
        : (sourceWalletId ?? walletId ?? '');

    // VALIDATING/EXECUTING at 0 confs = mempool; do not map SETTLED+0 into "Confirmado 6/6".
    var resolvedStatus = status;
    if (!isInternal &&
        !isLightning &&
        effectiveConfs <= 0 &&
        (resolvedStatus == TransactionStatus.confirmed ||
            json['status']?.toString().toUpperCase() == 'SETTLED')) {
      resolvedStatus = TransactionStatus.confirming;
    }

    String? resolvedDescription = memo;
    if (resolvedDescription == null || resolvedDescription.trim().isEmpty) {
      if (isPaymentLinkProvider) {
        resolvedDescription = isInternal
            ? 'Link de pagamento (interno)'
            : 'Link de pagamento (on-chain)';
      } else if (resolvedStatus == TransactionStatus.confirming &&
          !isInternal &&
          !isLightning) {
        resolvedDescription = isColdExternal
            ? 'Cold wallet — na mempool, aguardando confirmações'
            : 'On-chain — detectada, aguardando confirmações';
      } else if (isColdExternal && !isInternal) {
        resolvedDescription =
            isCredit ? 'Recebimento cold (on-chain)' : 'Envio cold (on-chain)';
      }
    }

    return Transaction(
      id: id,
      fromAddress: resolvedFrom,
      toAddress: resolvedTo,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      amountSatoshis: receiverAmountSats.abs(),
      feeSatoshis: effectiveNetworkFee,
      serviceFeeSatoshis: serviceFeeSats.abs(),
      status: resolvedStatus,
      type: txType,
      confirmations: effectiveConfs,
      timestamp: _parseDateTime(json['createdAt'] ?? json['timestamp']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ??
          _parseDateTime(json['createdAt'] ?? json['timestamp']),
      blockchainTxid: isInternal ? null : blockchainTxid,
      externalReference: externalReference,
      paymentHash: json['paymentHash']?.toString(),
      description: resolvedDescription,
      isInternal: isInternal,
      isLightning: isLightning,
      rail: rail.isNotEmpty
          ? rail
          : (isLightning
              ? 'LIGHTNING'
              : isInternal
                  ? 'INTERNAL'
                  : 'ONCHAIN'),
      provider: provider.isNotEmpty ? provider : null,
      // Only the stable code — never raw failureMessage in local storage/UI.
      failureCode: json['failureCode']?.toString(),
      cancellable: json['cancellable'] == true,
      cancelTarget: json['cancelTarget']?.toString(),
      paymentRequestId: json['paymentRequestId']?.toString(),
      paymentRequestPublicId: json['paymentRequestPublicId']?.toString(),
      paymentRequestStatus: json['paymentRequestStatus']?.toString(),
      walletLabel: json['walletLabel']?.toString(),
      sourceWalletLabel: json['sourceWalletLabel']?.toString(),
      destinationWalletLabel: json['destinationWalletLabel']?.toString(),
      counterpartyLabel: json['counterpartyLabel']?.toString(),
      hasNetworkFee: effectiveNetworkFee > 0,
      // Treat explicit 0 snapshots as missing — otherwise fiat UI shows R$0
      // while amountSatoshis is correct.
      displayAmountUsd: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountUsd',
        'historicalAmountUsd',
        'amountUsd',
      ])),
      displayAmountEur: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountEur',
        'historicalAmountEur',
        'amountEur',
      ])),
      displayAmountBrl: _parseNonZeroDouble(_firstJsonValue(json, const [
        'displayAmountBrl',
        'historicalAmountBrl',
        'amountBrl',
      ])),
      displayBtcUsd: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcUsd',
        'btcUsdSnapshot',
        'btcUsd',
      ])),
      displayBtcEur: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcEur',
        'btcEurSnapshot',
        'btcEur',
      ])),
      displayBtcBrl: _parsePositiveDouble(_firstJsonValue(json, const [
        'displayBtcBrl',
        'btcBrlSnapshot',
        'btcBrl',
      ])),
    );
  }

  static int _parseServiceFeeSats(
    Map<String, dynamic> json, {
    double networkFeeBtc = 0,
  }) {
    final fromSats = _parseInt(json['keroseneFeeSats']) ??
        _parseInt(json['serviceFeeSats']) ??
        _parseInt(json['platformFeeSats']) ??
        _parseInt(json['serviceFeeSatoshis']);
    if (fromSats != null) {
      return fromSats.abs();
    }
    final fromBtc = _parseDouble(_firstJsonValue(json, const [
      'serviceFeeBtc',
      'platformFeeBtc',
      'keroseneFeeBtc',
    ]));
    if (fromBtc != null && fromBtc != 0) {
      return (fromBtc.abs() * 100000000).round();
    }
    // Ignore networkFeeBtc — only service fee fields count.
    return 0;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  /// Positive sats only — 0/null are treated as absent for amount fallbacks.
  static int? _parsePositiveInt(dynamic value) {
    final parsed = _parseInt(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  /// Fiat snapshot that is missing or explicitly 0 → null (recompute from BTC).
  static double? _parseNonZeroDouble(dynamic value) {
    final parsed = _parseDouble(value);
    if (parsed == null || parsed == 0) return null;
    return parsed;
  }

  /// Rate snapshot must be positive to be usable.
  static double? _parsePositiveDouble(dynamic value) {
    final parsed = _parseDouble(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static int _parseBtcToSats(dynamic value) {
    if (value == null) return 0;
    if (value is num) {
      final d = value.toDouble();
      if (d <= 0) return 0;
      if (d >= 1000) return d.round();
      return (d * 100000000).round();
    }
    final str = value.toString().trim();
    if (str.isEmpty) return 0;
    final d = double.tryParse(str.replaceAll(',', '.'));
    if (d == null || d <= 0) return 0;
    if (d >= 1000) return d.round();
    return (d * 100000000).round();
  }

  static Object? _firstJsonValue(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    // Keep parsing logic centralized (UTC bare ISO → local).
    // Inline copy of AppDateTime.parse to avoid circular imports in domain.
    if (value == null) return null;
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value.toLocal();
    }
    if (value is int) {
      final ms = value > 20000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;
    final hasExplicitOffset = RegExp(
      r'(z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(normalized);
    if (parsed.isUtc || hasExplicitOffset) {
      return parsed.toLocal();
    }
    // Bare ISO from KFE LocalDateTime (JVM UTC) → treat as UTC wall clock.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  static TransactionType _resolveType({
    required String typeField,
    required String transferTypeField,
    required String contextField,
    required String directionField,
    required double amountVal,
    required int? currentUserId,
    required int? senderUserId,
    required int? receiverUserId,
    required String? currentUserIdentifier,
    required String? senderIdentifier,
    required String? receiverIdentifier,
  }) {
    final typeParts = [
      typeField,
      transferTypeField,
      directionField,
      contextField,
    ].where((value) => value.trim().isNotEmpty).join('|');

    if (typeField == 'INTERNAL' || typeField == 'TRANSFER') {
      if (currentUserId != null) {
        if (senderUserId == currentUserId && receiverUserId != currentUserId) {
          return TransactionType.send;
        }
        if (receiverUserId == currentUserId && senderUserId != currentUserId) {
          return TransactionType.receive;
        }
      }
      if (_containsAny(directionField, const [
        'OUTGOING',
        'OUTBOUND',
        'DEBIT',
        'SENT',
        'SEND',
        'PAYER',
      ])) {
        return TransactionType.send;
      }
      if (_containsAny(directionField, const [
        'INCOMING',
        'INBOUND',
        'CREDIT',
        'RECEIVED',
        'RECEIVE',
        'PAYEE',
      ])) {
        return TransactionType.receive;
      }
      final currentIdentifier = _normalizeIdentity(currentUserIdentifier);
      final sender = _normalizeIdentity(senderIdentifier);
      final receiver = _normalizeIdentity(receiverIdentifier);
      if (currentIdentifier.isNotEmpty) {
        if (sender == currentIdentifier && receiver != currentIdentifier) {
          return TransactionType.send;
        }
        if (receiver == currentIdentifier && sender != currentIdentifier) {
          return TransactionType.receive;
        }
      }
    }

    if (_containsAny(typeParts, const [
      'EXTERNAL_WITHDRAWAL',
      'WITHDRAWAL',
      'TRANSACTION_SEND',
      'TRANSFER_SENT',
      'PAYMENT_SENT',
      'PAYMENT_INTERNAL_DEBIT',
      'INTERNAL_DEBIT',
      'LEDGER_DEBIT',
      'OUTBOUND_PAYMENT',
      'OUTBOUND',
      'OUTGOING',
      'DEBIT',
      'SEND',
      'SENT',
      'CASHOUT',
      'CASH_OUT',
    ])) {
      return TransactionType.withdrawal;
    }

    if (_containsAny(typeParts, const [
      'EXTERNAL_DEPOSIT',
      'DEPOSIT',
      'TRANSACTION_RECEIVE',
      'TRANSFER_RECEIVED',
      'PAYMENT_RECEIVED',
      'PAYMENT_INTERNAL_CREDIT',
      'INTERNAL_CREDIT',
      'LEDGER_CREDIT',
      'INBOUND_INVOICE',
      'INBOUND',
      'INCOMING',
      'CREDIT',
      'RECEIVE',
      'RECEIVED',
    ])) {
      return TransactionType.deposit;
    }

    return amountVal < 0 ? TransactionType.send : TransactionType.receive;
  }

  static bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  static String _normalizeIdentity(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'^@+'), '');
  }

  static TransactionStatus _resolveStatus({
    required String? rawStatus,
    required int confirmations,
  }) {
    final normalized = rawStatus?.toUpperCase() ?? 'PENDING';

    switch (normalized) {
      case 'CONCLUDED':
      case 'COMPLETED':
      case 'PAID':
        return TransactionStatus.confirmed;
      case 'VERIFYING_ONBOARDING':
        return TransactionStatus.confirming;
      case 'PENDING':
        return confirmations > 0
            ? TransactionStatus.confirming
            : TransactionStatus.pending;
      case 'CANCELED':
      case 'CANCELLED':
      case 'EXPIRED':
        return TransactionStatus.cancelled;
      case 'FAILED':
        return TransactionStatus.failed;
      default:
        return confirmations > 0
            ? TransactionStatus.confirming
            : TransactionStatus.pending;
    }
  }

  static TransactionStatus _resolveKfeStatus(
    String? rawStatus, {
    int confirmations = 0,
    bool isInternal = false,
    bool isLightning = false,
  }) {
    switch (rawStatus?.toUpperCase()) {
      case 'SETTLED':
        return TransactionStatus.confirmed;
      case 'CANCELLED':
      case 'CANCELED':
      case 'EXPIRED':
      case 'HIDDEN':
        return TransactionStatus.cancelled;
      case 'FAILED':
        return TransactionStatus.failed;
      case 'REQUIRES_RECONCILIATION':
        // Not "failed" — funds may remain locked pending ops.
        return TransactionStatus.reconciling;
      case 'EXECUTING':
      case 'LOCKED':
      case 'QUORUM_SYNC':
      case 'VALIDATING':
        // Ledger-internal settles by status, not block confs.
        if (isInternal || isLightning) {
          return TransactionStatus.pending;
        }
        // On-chain mempool (0 conf) and partial confs both use confirming UI
        // ("Na mempool" / "N/6") — not a generic pending.
        return TransactionStatus.confirming;
      case 'INTENT':
      default:
        return TransactionStatus.pending;
    }
  }

  @override
  List<Object?> get props => [
        id,
        fromAddress,
        toAddress,
        walletId,
        sourceWalletId,
        destinationWalletId,
        senderDisplayName,
        receiverDisplayName,
        walletLabel,
        sourceWalletLabel,
        destinationWalletLabel,
        counterpartyLabel,
        amountSatoshis,
        feeSatoshis,
        serviceFeeSatoshis,
        status,
        type,
        confirmations,
        timestamp,
        updatedAt,
        blockHash,
        blockHeight,
        blockchainTxid,
        externalReference,
        invoiceId,
        lightningInvoice,
        paymentHash,
        externalTransferId,
        externalTransferStatus,
        externalTransferType,
        description,
        isInternal,
        isLightning,
        rail,
        provider,
        failureCode,
        cancellable,
        cancelTarget,
        paymentRequestId,
        paymentRequestPublicId,
        paymentRequestStatus,
        hasNetworkFee,
        displayAmountUsd,
        displayAmountEur,
        displayAmountBrl,
        displayBtcUsd,
        displayBtcEur,
        displayBtcBrl,
      ];
}

/// Status da transação
enum TransactionStatus {
  /// Pendente (não confirmada)
  pending('Pending', 'Waiting for confirmation'),

  /// Confirmando (1-5 confirmações)
  confirming('Confirming', 'Being confirmed'),

  /// Confirmada (6+ confirmações)
  confirmed('Confirmed', 'Transaction confirmed'),

  /// Cancelada ou expirada (sem liquidação)
  cancelled('Cancelled', 'Transaction cancelled'),

  /// Falhou
  failed('Failed', 'Transaction failed'),

  /// Em análise / reconciliação (fundos podem estar reservados — não é falha final)
  reconciling('Needs review', 'Transaction needs review');

  const TransactionStatus(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Tipo de transação
enum TransactionType {
  /// Envio de Bitcoin
  send('Send', 'Sent Bitcoin'),

  /// Recebimento de Bitcoin
  receive('Receive', 'Received Bitcoin'),

  /// Swap/Exchange
  swap('Swap', 'Token swap'),

  /// Taxa de rede
  fee('Fee', 'Network fee'),

  /// Saque (Withdrawal)
  withdrawal('Withdrawal', 'Sent Bitcoin to external address'),

  /// Depósito (Deposit)
  deposit('Deposit', 'Received Bitcoin from external address');

  const TransactionType(this.displayName, this.description);

  final String displayName;
  final String description;
}
