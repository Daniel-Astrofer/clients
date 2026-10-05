import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

class OnboardingProgress {
  final bool hasCustodialWallet;
  final bool hasDeposit;
  final bool hasInternalTransfer;

  const OnboardingProgress({
    required this.hasCustodialWallet,
    required this.hasDeposit,
    required this.hasInternalTransfer,
  });

  int get completedSteps {
    int count = 0;
    if (hasCustodialWallet) count++;
    if (hasDeposit) count++;
    if (hasInternalTransfer) count++;
    return count;
  }

  bool get isAllCompleted => completedSteps == 3;
}

final onboardingProgressProvider = Provider<OnboardingProgress>((ref) {
  // Booleans only — never re-emit because a new List instance arrived.
  final hasCustodialWallet = ref.watch(
    walletProvider.select((w) {
      if (w is! WalletLoaded) return false;
      return w.wallets.any((wallet) => wallet.isKeroseneCustody);
    }),
  );
  final hasDeposit = ref.watch(
    transactionHistoryProvider.select((async) {
      final txs = async.asData?.value;
      if (txs == null || txs.isEmpty) return false;
      for (final t in txs) {
        if (t.isCredit || t.type == TransactionType.deposit) return true;
      }
      return false;
    }),
  );
  final hasInternalTransfer = ref.watch(
    transactionHistoryProvider.select((async) {
      final txs = async.asData?.value;
      if (txs == null || txs.isEmpty) return false;
      for (final t in txs) {
        if (t.isInternal &&
            t.status != TransactionStatus.failed &&
            t.status != TransactionStatus.cancelled) {
          return true;
        }
      }
      return false;
    }),
  );

  return OnboardingProgress(
    hasCustodialWallet: hasCustodialWallet,
    hasDeposit: hasDeposit,
    hasInternalTransfer: hasInternalTransfer,
  );
});
