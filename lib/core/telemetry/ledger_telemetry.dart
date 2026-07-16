import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local counters for extrato sync health (no PII).
///
/// Lives under `core/telemetry` so secure storage and datasources can record
/// without `core → features` imports. Values live in SharedPreferences and
/// never include txids, amounts, or addresses.
class LedgerTelemetrySnapshot {
  final int mergeUpgraded;
  final int offlineServed;
  final int statementFallback;
  final int macDiscarded;
  final int fullPulls;
  final int incrementalPulls;
  final DateTime? lastEventAt;

  const LedgerTelemetrySnapshot({
    this.mergeUpgraded = 0,
    this.offlineServed = 0,
    this.statementFallback = 0,
    this.macDiscarded = 0,
    this.fullPulls = 0,
    this.incrementalPulls = 0,
    this.lastEventAt,
  });

  LedgerTelemetrySnapshot copyWith({
    int? mergeUpgraded,
    int? offlineServed,
    int? statementFallback,
    int? macDiscarded,
    int? fullPulls,
    int? incrementalPulls,
    DateTime? lastEventAt,
  }) {
    return LedgerTelemetrySnapshot(
      mergeUpgraded: mergeUpgraded ?? this.mergeUpgraded,
      offlineServed: offlineServed ?? this.offlineServed,
      statementFallback: statementFallback ?? this.statementFallback,
      macDiscarded: macDiscarded ?? this.macDiscarded,
      fullPulls: fullPulls ?? this.fullPulls,
      incrementalPulls: incrementalPulls ?? this.incrementalPulls,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }
}

class LedgerTelemetry {
  LedgerTelemetry._();

  static const _prefix = 'ledger_telem_v1';

  static Future<void> recordMergeUpgraded() => _inc('merge_upgraded');
  static Future<void> recordOfflineServed() => _inc('offline_served');
  static Future<void> recordStatementFallback() => _inc('statement_fallback');
  static Future<void> recordMacDiscarded() => _inc('mac_discarded');
  static Future<void> recordFullPull() => _inc('full_pulls');
  static Future<void> recordIncrementalPull() => _inc('incremental_pulls');

  static Future<void> _inc(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final full = '$_prefix:$key';
      final next = (prefs.getInt(full) ?? 0) + 1;
      await prefs.setInt(full, next);
      await prefs.setInt(
        '$_prefix:last_event_ms',
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LedgerTelemetry: $e');
      }
    }
  }

  static Future<LedgerTelemetrySnapshot> snapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('$_prefix:last_event_ms');
      return LedgerTelemetrySnapshot(
        mergeUpgraded: prefs.getInt('$_prefix:merge_upgraded') ?? 0,
        offlineServed: prefs.getInt('$_prefix:offline_served') ?? 0,
        statementFallback: prefs.getInt('$_prefix:statement_fallback') ?? 0,
        macDiscarded: prefs.getInt('$_prefix:mac_discarded') ?? 0,
        fullPulls: prefs.getInt('$_prefix:full_pulls') ?? 0,
        incrementalPulls: prefs.getInt('$_prefix:incremental_pulls') ?? 0,
        lastEventAt: lastMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true),
      );
    } catch (_) {
      return const LedgerTelemetrySnapshot();
    }
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('$_prefix:')) {
        await prefs.remove(key);
      }
    }
  }
}

final ledgerTelemetrySnapshotProvider =
    FutureProvider<LedgerTelemetrySnapshot>((ref) {
  return LedgerTelemetry.snapshot();
});
