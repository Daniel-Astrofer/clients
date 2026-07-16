import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_refresh.dart';

/// Dirty flag set by background/WS when money may have moved while UI was
/// paused. Cleared after a successful [refreshFinancialProjectionUi].
class FinancialDirtyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markDirty() => state = true;

  void clear() => state = false;
}

final financialDirtyProvider =
    NotifierProvider<FinancialDirtyNotifier, bool>(FinancialDirtyNotifier.new);

/// Call when the app returns to foreground — refreshes if dirty.
Future<void> refreshFinancialProjectionIfDirty(WidgetRef ref) async {
  if (!ref.read(financialDirtyProvider)) return;
  await refreshFinancialProjectionUi(ref);
  ref.read(financialDirtyProvider.notifier).clear();
}
