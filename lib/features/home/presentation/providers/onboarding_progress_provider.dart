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
  final walletState = ref.watch(walletProvider);
  final txHistoryAsync = ref.watch(transactionHistoryProvider);

  // We read the lists from current states, defaulting to empty if loading for the first time
  final wallets = walletState is WalletLoaded ? walletState.wallets : const [];
  final transactions = txHistoryAsync.value ?? const [];

  final hasCustodialWallet = wallets.any((w) => w.isKeroseneCustody);
  final hasDeposit = transactions.any((t) => t.isCredit || t.type == TransactionType.deposit);
  final hasInternalTransfer = transactions.any(
    (t) =>
        t.isInternal &&
        t.status != TransactionStatus.failed &&
        t.status != TransactionStatus.cancelled,
  );

  return OnboardingProgress(
    hasCustodialWallet: hasCustodialWallet,
    hasDeposit: hasDeposit,
    hasInternalTransfer: hasInternalTransfer,
  );
});
