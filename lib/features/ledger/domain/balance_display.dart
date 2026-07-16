import 'ledger_row.dart';

/// Helpers for wallet balance presentation by custody kind.
///
/// Canonical display rules (aligned with KFE dashboard + WS primarySats):
/// - WATCH_ONLY / cold → observed only
/// - INTERNAL / CUSTODIAL_ONCHAIN → available (ledger); observed is reconciliation only
class BalanceDisplayRules {
  const BalanceDisplayRules._();

  /// Cold (WATCH_ONLY) → observed; custodial/internal → available.
  static int primarySats({
    required String kind,
    required int availableSats,
    required int observedSats,
  }) {
    if (kind.toUpperCase() == 'WATCH_ONLY') return observedSats;
    return availableSats;
  }

  /// Whether a WS/realtime event that only updates chain observation should
  /// leave spendable (available) untouched.
  static bool observedEventMustNotClobberSpendable(String kind) {
    final k = kind.toUpperCase();
    return k != 'WATCH_ONLY' && k.isNotEmpty;
  }

  static bool showObservedAsSubtitle({
    required String kind,
    required int availableSats,
    required int observedSats,
  }) {
    return kind.toUpperCase() == 'CUSTODIAL_ONCHAIN' &&
        observedSats != availableSats;
  }

  static BalanceSnapshot snapshot({
    required String walletId,
    required String kind,
    required String label,
    required int availableSats,
    required int observedSats,
    int pendingSats = 0,
    int lockedSats = 0,
    DateTime? updatedAt,
  }) {
    return BalanceSnapshot(
      walletId: walletId,
      kind: kind,
      label: label,
      availableSats: availableSats,
      observedSats: observedSats,
      pendingSats: pendingSats,
      lockedSats: lockedSats,
      updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
