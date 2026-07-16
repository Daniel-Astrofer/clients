import 'ledger_row.dart';

/// Field-level merge for LocalLedgerSync.
///
/// See docs/frontend/LOCAL_LEDGER_SYNC.md §5.
class LedgerMerge {
  const LedgerMerge._();

  /// Primary key for a projection row.
  static String rowKey(LedgerRow row) {
    final id = row.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    final txid = row.blockchainTxid?.trim() ?? '';
    if (txid.isNotEmpty) {
      final side = switch (row.direction) {
        LedgerDirection.outbound => 'out',
        LedgerDirection.inbound => 'in',
        LedgerDirection.internal => 'int',
      };
      return 'chain:$txid:$side';
    }
    return 'id:unknown';
  }

  /// Merge [remote] onto [local] (same logical id). Prefer remote for live fields
  /// when [remote.updatedAt] is not older than local.
  static LedgerRow mergeRow(LedgerRow local, LedgerRow remote) {
    final remoteNewer = !remote.updatedAt.isBefore(local.updatedAt);
    final remoteOlder = remote.updatedAt.isBefore(local.updatedAt);

    final confs = _mergeConfirmations(
      local: local,
      remote: remote,
      remoteNewer: remoteNewer,
      remoteOlder: remoteOlder,
    );
    final status = _mergeStatus(
      local: local,
      remote: remote,
      remoteNewer: remoteNewer,
      remoteOlder: remoteOlder,
      confs: confs,
    );

    final amountSats = remoteNewer ? remote.amountSats : local.amountSats;
    final feeSats = remoteNewer ? remote.feeSats : local.feeSats;
    final serviceFeeSats =
        remoteNewer ? remote.serviceFeeSats : local.serviceFeeSats;

    return LedgerRow(
      id: local.id.isNotEmpty ? local.id : remote.id,
      direction: remoteNewer ? remote.direction : local.direction,
      rail: remoteNewer ? remote.rail : local.rail,
      status: status,
      confirmations: confs,
      amountSats: amountSats,
      feeSats: feeSats,
      serviceFeeSats: serviceFeeSats,
      sourceWalletId: _preferNonEmpty(
        remoteNewer ? remote.sourceWalletId : local.sourceWalletId,
        remoteNewer ? local.sourceWalletId : remote.sourceWalletId,
      ),
      destinationWalletId: _preferNonEmpty(
        remoteNewer ? remote.destinationWalletId : local.destinationWalletId,
        remoteNewer ? local.destinationWalletId : remote.destinationWalletId,
      ),
      blockchainTxid: _preferNonEmpty(
        remoteNewer ? remote.blockchainTxid : local.blockchainTxid,
        remoteNewer ? local.blockchainTxid : remote.blockchainTxid,
      ),
      externalReference: _preferNonEmpty(
        remoteNewer ? remote.externalReference : local.externalReference,
        remoteNewer ? local.externalReference : remote.externalReference,
      ),
      provider: _preferNonEmpty(
        remoteNewer ? remote.provider : local.provider,
        remoteNewer ? local.provider : remote.provider,
      ),
      memo: _preferNonEmpty(
        remoteNewer ? remote.memo : local.memo,
        remoteNewer ? local.memo : remote.memo,
      ),
      createdAt: local.createdAt.isBefore(remote.createdAt)
          ? local.createdAt
          : remote.createdAt,
      updatedAt: remote.updatedAt.isAfter(local.updatedAt)
          ? remote.updatedAt
          : local.updatedAt,
      localOnly: false,
      tombstone: remote.tombstone || local.tombstone,
      source: remote.source == LedgerSource.remote
          ? LedgerSource.remote
          : local.source,
    );
  }

  /// Union of [localRows] and [remoteRows] keyed by [rowKey].
  /// Remote rows win field-level on conflict; local-only ids are kept.
  static List<LedgerRow> mergeLists({
    required List<LedgerRow> localRows,
    required List<LedgerRow> remoteRows,
    int maxEntries = 500,
  }) {
    final map = <String, LedgerRow>{};

    for (final row in localRows) {
      if (row.tombstone) continue;
      final key = rowKey(row);
      map[key] = row;
    }

    for (final remote in remoteRows) {
      if (remote.tombstone) continue;
      final key = rowKey(remote);
      final local = map[key];
      if (local == null) {
        map[key] = remote.copyWith(localOnly: false);
      } else {
        map[key] = mergeRow(local, remote);
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length > maxEntries) {
      return list.sublist(0, maxEntries);
    }
    return list;
  }

  /// Rows that touch [walletId] as source or destination.
  static List<LedgerRow> filterByWallet(List<LedgerRow> rows, String walletId) {
    final id = walletId.trim();
    if (id.isEmpty) return const [];
    return rows
        .where(
          (r) =>
              r.sourceWalletId == id ||
              r.destinationWalletId == id,
        )
        .toList(growable: false);
  }

  static int _mergeConfirmations({
    required LedgerRow local,
    required LedgerRow remote,
    required bool remoteNewer,
    required bool remoteOlder,
  }) {
    if (remoteOlder) {
      // T2: do not regress confs when remote is stale.
      return local.confirmations >= remote.confirmations
          ? local.confirmations
          : remote.confirmations;
    }
    if (remoteNewer && remote.updatedAt.isAfter(local.updatedAt)) {
      // Strictly newer remote: take remote confs (may still be 0 if reorg/reset).
      // Prefer never decreasing when remote confs is lower but same second — use max.
      if (remote.confirmations >= local.confirmations) {
        return remote.confirmations;
      }
      // Newer remote with lower confs: only accept if remote is statement-quality?
      // Design: "R if R.updatedAt ≥ L" — allow remote but avoid accidental 0 wipe
      // when remote is statement (frozen 0) and local has progress.
      if (remote.source == LedgerSource.statement &&
          local.confirmations > remote.confirmations) {
        return local.confirmations;
      }
      return remote.confirmations;
    }
    // Same epoch (equal updatedAt): max confs (T6).
    return local.confirmations > remote.confirmations
        ? local.confirmations
        : remote.confirmations;
  }

  static LedgerStatus _mergeStatus({
    required LedgerRow local,
    required LedgerRow remote,
    required bool remoteNewer,
    required bool remoteOlder,
    required int confs,
  }) {
    if (remoteOlder) {
      return _rank(local.status) >= _rank(remote.status)
          ? local.status
          : remote.status;
    }
    if (remoteNewer && remote.updatedAt.isAfter(local.updatedAt)) {
      if (remote.source == LedgerSource.statement &&
          _rank(local.status) > _rank(remote.status) &&
          confs > 0) {
        return local.status;
      }
      return remote.status;
    }
    // Equal timestamps: more terminal status.
    return _rank(local.status) >= _rank(remote.status)
        ? local.status
        : remote.status;
  }

  static int _rank(LedgerStatus s) {
    return switch (s) {
      LedgerStatus.confirmed => 5,
      LedgerStatus.confirming => 4,
      LedgerStatus.pending => 3,
      LedgerStatus.failed => 2,
      LedgerStatus.cancelled => 1,
    };
  }

  static String? _preferNonEmpty(String? primary, String? fallback) {
    final p = primary?.trim();
    if (p != null && p.isNotEmpty) return p;
    final f = fallback?.trim();
    if (f != null && f.isNotEmpty) return f;
    return null;
  }
}
