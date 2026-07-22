import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_refresh.dart';

/// Dirty flag set by background/WS when money may have moved while UI was
/// paused. Cleared only after a **successful** [refreshFinancialProjectionUi]
/// (both wallets + history). Tor flaps must not clear this on partial failure.
class FinancialDirtyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markDirty() => state = true;

  void clear() => state = false;
}

final financialDirtyProvider =
    NotifierProvider<FinancialDirtyNotifier, bool>(FinancialDirtyNotifier.new);

/// Call when the app returns to foreground — refreshes if dirty.
///
/// Always uses [forceFullHistory]: under Tor (and assuming kfe→server fan-out
/// is similarly latent), incremental `?since=` can miss the settle that landed
/// while the socket was down.
Future<void> refreshFinancialProjectionIfDirty(WidgetRef ref) async {
  if (!ref.read(financialDirtyProvider)) return;
  final ok = await refreshFinancialProjectionUi(
    ref,
    forceFullHistory: true,
    scope: FinancialRefreshScope.full,
  );
  if (ok) {
    ref.read(financialDirtyProvider.notifier).clear();
  }
}
