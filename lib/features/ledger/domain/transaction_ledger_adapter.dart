import 'package:kerosene/features/movement/domain/entities/transaction.dart';

import 'ledger_merge.dart';
import 'ledger_row.dart';

/// Maps [Transaction] ↔ [LedgerRow] for merge without changing the UI entity yet.
class TransactionLedgerAdapter {
  const TransactionLedgerAdapter._();

  static LedgerRow fromTransaction(
    Transaction tx, {
    LedgerSource source = LedgerSource.remote,
    DateTime? updatedAt,
  }) {
    return LedgerRow(
      id: tx.id.trim(),
      direction: _direction(tx),
      rail: _rail(tx),
      status: _status(tx.status),
      confirmations: tx.confirmations,
      amountSats: tx.amountSatoshis,
      feeSats: tx.feeSatoshis,
      serviceFeeSats: tx.serviceFeeSatoshis,
      sourceWalletId: tx.sourceWalletId,
      destinationWalletId: tx.destinationWalletId,
      blockchainTxid: tx.blockchainTxid,
      externalReference: tx.externalReference,
      provider: tx.provider,
      memo: tx.description,
      createdAt: tx.timestamp,
      updatedAt: updatedAt ?? tx.effectiveUpdatedAt,
      localOnly: source == LedgerSource.local,
      source: source,
    );
  }

  /// Merge two [Transaction]s with the same id using field-level rules.
  static Transaction mergeTransactions(Transaction local, Transaction remote) {
    final merged = LedgerMerge.mergeRow(
      fromTransaction(local, source: LedgerSource.local),
      fromTransaction(remote, source: LedgerSource.remote),
    );
    return _applyRowToTransaction(local, remote, merged);
  }

  /// Union local + remote transaction lists (design §5.2).
  static List<Transaction> mergeTransactionLists({
    required List<Transaction> localRows,
    required List<Transaction> remoteRows,
    int maxEntries = 500,
  }) {
    final localLedger = localRows
        .map((t) => fromTransaction(t, source: LedgerSource.local))
        .toList(growable: false);
    final remoteLedger = remoteRows
        .map((t) => fromTransaction(t, source: LedgerSource.remote))
        .toList(growable: false);

    final mergedRows = LedgerMerge.mergeLists(
      localRows: localLedger,
      remoteRows: remoteLedger,
      maxEntries: maxEntries,
    );

    // Rebuild Transaction objects: prefer remote entity shell when present.
    final remoteById = <String, Transaction>{
      for (final t in remoteRows)
        if (t.id.trim().isNotEmpty) t.id.trim(): t,
    };
    final localById = <String, Transaction>{
      for (final t in localRows)
        if (t.id.trim().isNotEmpty) t.id.trim(): t,
    };

    final out = <Transaction>[];
    for (final row in mergedRows) {
      final id = row.id.trim();
      final remote = remoteById[id];
      final local = localById[id];
      if (remote != null && local != null) {
        out.add(_applyRowToTransaction(local, remote, row));
      } else if (remote != null) {
        out.add(_applyRowToTransaction(remote, remote, row));
      } else if (local != null) {
        out.add(_applyRowToTransaction(local, local, row));
      }
    }
    out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out;
  }

  static Transaction _applyRowToTransaction(
    Transaction a,
    Transaction b,
    LedgerRow row,
  ) {
    // Prefer remote shell for display fields (names, fiat freezes) when available.
    final shell = b;
    return Transaction(
      id: row.id.isNotEmpty ? row.id : shell.id,
      fromAddress: shell.fromAddress,
      toAddress: shell.toAddress,
      walletId: shell.walletId,
      sourceWalletId: row.sourceWalletId ?? shell.sourceWalletId,
      destinationWalletId: row.destinationWalletId ?? shell.destinationWalletId,
      senderDisplayName: shell.senderDisplayName,
      receiverDisplayName: shell.receiverDisplayName,
      walletLabel: shell.walletLabel ?? a.walletLabel,
      sourceWalletLabel: shell.sourceWalletLabel ?? a.sourceWalletLabel,
      destinationWalletLabel:
          shell.destinationWalletLabel ?? a.destinationWalletLabel,
      counterpartyLabel: shell.counterpartyLabel ?? a.counterpartyLabel,
      amountSatoshis: row.amountSats,
      feeSatoshis: row.feeSats,
      serviceFeeSatoshis: row.serviceFeeSats,
      status: _toTxStatus(row.status),
      type: shell.type,
      confirmations: row.confirmations,
      timestamp: row.createdAt,
      updatedAt: row.updatedAt,
      blockHash: shell.blockHash,
      blockHeight: shell.blockHeight,
      blockchainTxid: row.blockchainTxid ?? shell.blockchainTxid,
      externalReference: row.externalReference ?? shell.externalReference,
      invoiceId: shell.invoiceId,
      lightningInvoice: shell.lightningInvoice,
      paymentHash: shell.paymentHash,
      externalTransferId: shell.externalTransferId,
      externalTransferStatus: shell.externalTransferStatus,
      externalTransferType: shell.externalTransferType,
      description: row.memo ?? shell.description,
      isInternal: shell.isInternal,
      isLightning: shell.isLightning,
      rail: shell.rail ?? a.rail,
      provider: row.provider ?? shell.provider ?? a.provider,
      failureCode: shell.failureCode ?? a.failureCode,
      hasNetworkFee: shell.hasNetworkFee || row.feeSats > 0,
      displayAmountUsd: shell.displayAmountUsd ?? a.displayAmountUsd,
      displayAmountEur: shell.displayAmountEur ?? a.displayAmountEur,
      displayAmountBrl: shell.displayAmountBrl ?? a.displayAmountBrl,
      displayBtcUsd: shell.displayBtcUsd ?? a.displayBtcUsd,
      displayBtcEur: shell.displayBtcEur ?? a.displayBtcEur,
      displayBtcBrl: shell.displayBtcBrl ?? a.displayBtcBrl,
    );
  }

  /// Drop synthetic payment-link rows when a live KFE row already covers the
  /// same settlement (txid / external ref / payment hash).
  static List<Transaction> dedupePaymentLinkOverlays(
    List<Transaction> rows,
  ) {
    if (rows.length < 2) return rows;

    final kfeRefs = <String>{};
    for (final tx in rows) {
      if (tx.id.startsWith('pl_')) continue;
      final txid = (tx.blockchainTxid ?? '').trim().toLowerCase();
      if (txid.isNotEmpty) kfeRefs.add('txid:$txid');
      final ext = (tx.externalReference ?? '').trim().toLowerCase();
      if (ext.isNotEmpty && ext.length >= 8) kfeRefs.add('ext:$ext');
      final hash = (tx.paymentHash ?? '').trim().toLowerCase();
      if (hash.isNotEmpty) kfeRefs.add('ph:$hash');
      // Paid link often lands as provider PAYMENT_LINK on the KFE UUID.
      if (tx.isPaymentLink ||
          (tx.provider ?? '').toUpperCase().contains('PAYMENT_LINK')) {
        final id = tx.id.trim().toLowerCase();
        if (id.isNotEmpty) kfeRefs.add('id:$id');
      }
    }

    if (kfeRefs.isEmpty) return rows;

    return rows.where((tx) {
      if (!tx.id.startsWith('pl_')) return true;
      final txid = (tx.blockchainTxid ?? '').trim().toLowerCase();
      if (txid.isNotEmpty && kfeRefs.contains('txid:$txid')) return false;
      final ext = (tx.externalReference ?? '').trim().toLowerCase();
      if (ext.isNotEmpty && kfeRefs.contains('ext:$ext')) return false;
      final hash = (tx.paymentHash ?? '').trim().toLowerCase();
      if (hash.isNotEmpty && kfeRefs.contains('ph:$hash')) return false;
      // Drop cancelled/expired synthetic links when any live activity exists
      // with the same short id suffix.
      final bare = tx.id.replaceFirst('pl_', '').trim().toLowerCase();
      if (bare.isNotEmpty && kfeRefs.contains('id:$bare')) return false;
      return true;
    }).toList(growable: false);
  }

  static LedgerDirection _direction(Transaction tx) {
    if (tx.isInternal && !tx.isLightning) return LedgerDirection.internal;
    if (tx.isDebit) return LedgerDirection.outbound;
    return LedgerDirection.inbound;
  }

  static LedgerRail _rail(Transaction tx) {
    if (tx.isLightning) return LedgerRail.lightning;
    if (tx.isInternal) return LedgerRail.internal;
    return LedgerRail.onchain;
  }

  static LedgerStatus _status(TransactionStatus s) {
    return switch (s) {
      TransactionStatus.pending => LedgerStatus.pending,
      TransactionStatus.confirming => LedgerStatus.confirming,
      TransactionStatus.confirmed => LedgerStatus.confirmed,
      TransactionStatus.failed => LedgerStatus.failed,
      TransactionStatus.cancelled => LedgerStatus.cancelled,
      // Surface reconciling as failed in ledger merge clock (needs review).
      TransactionStatus.reconciling => LedgerStatus.failed,
    };
  }

  static TransactionStatus _toTxStatus(LedgerStatus s) {
    return switch (s) {
      LedgerStatus.pending => TransactionStatus.pending,
      LedgerStatus.confirming => TransactionStatus.confirming,
      LedgerStatus.confirmed => TransactionStatus.confirmed,
      LedgerStatus.failed => TransactionStatus.failed,
      LedgerStatus.cancelled => TransactionStatus.cancelled,
    };
  }
}
