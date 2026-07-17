import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/core/security/device_credential_error_ux.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_spend_coordinator.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/domain/payment_security_guards.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';

/// @Deprecated Prefer NetworkFeeCertainty.unknownUntilPay — kept for older call sites.
const defaultLightningRoutingFeeBtc = 0.000001;

Future<dynamic> confirmSendPayment({
  required BuildContext context,
  required BuildContext confirmationContext,
  required WidgetRef ref,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double amount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required String? pendingPaymentLinkId,
  required Future<AccountSecurityProfile> Function(Wallet wallet)
      resolveSecurityProfile,
  required Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification,
  required String? Function(String toAddress) resolveRecentDestinationLabel,
  required String Function(String toAddress) resolveRecentDestinationAddress,
  required bool Function() isMounted,

  /// When true, first-send was already acknowledged on the review screen
  /// (inline checkbox). Skips the legacy AlertDialog path.
  bool firstSendAcknowledgedInReview = false,
}) async {
  final l10n = context.tr;

  // Fail-closed network check for on-chain destinations.
  if (destination.isOnChain) {
    final networkError = networkMismatchMessage(toAddress, context: context);
    if (networkError != null) {
      SnackbarHelper.showError(networkError);
      return null;
    }
    if (!firstSendAcknowledgedInReview) {
      final ok = await confirmFirstTimeOnchainAddress(
        context: confirmationContext,
        address: toAddress,
      );
      if (!ok || !isMounted() || !confirmationContext.mounted) {
        return null;
      }
    }
  }

  // Quote must still be fresh at confirm time for external on-chain.
  if (destination.isOnChain && feeQuote.isQuoteExpired) {
    SnackbarHelper.showError(SendMoneyCopy.networkFeeUnavailable(context));
    return null;
  }

  final profile = await resolveSecurityProfile(wallet);
  if (!isMounted() || !confirmationContext.mounted) return null;

  final isColdSource =
      wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable;
  final authResult = await TransactionAuthGate.show(
    confirmationContext,
    profile: profile,
    // Cold PSBT create requires TOTP on the KFE API.
    forceTotp: isColdSource,
    // Device biometrics may fail open only when policy does not need factors;
    // server factors (TOTP/passkey/passphrase) are never skipped by the gate.
    allowDeviceAuthUnavailable: false,
  );

  if (!isMounted() || !confirmationContext.mounted) return null;

  // User back/cancel during PIN, biometrics, or factor sheets — stay on review.
  if (authResult.isCancelled) {
    return null;
  }
  if (authResult.isUnavailable) {
    SnackbarHelper.showInfo(l10n.sendMoneyAuthFailed);
    return null;
  }
  if (!authResult.isAuthenticated) {
    SnackbarHelper.showError(l10n.sendMoneyAuthFailed);
    return null;
  }

  if (pendingPaymentLinkId != null) {
    if (wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable) {
      SnackbarHelper.showError(SendMoneyCopy.coldNoPaymentLink(confirmationContext));
      return null;
    }
    return _confirmPaymentLink(
      confirmationContext: confirmationContext,
      ref: ref,
      wallet: wallet,
      destination: destination,
      amount: amount,
      toAddress: toAddress,
      linkId: pendingPaymentLinkId,
      authResult: authResult,
      showSentTransactionNotification: showSentTransactionNotification,
      isMounted: isMounted,
    );
  }

  // Cold / watch-only: local seed signs PSBT; same review + auth gate as above.
  if (wallet.isColdWallet || wallet.isSelfCustody || !wallet.spendable) {
    return _confirmColdSend(
      confirmationContext: confirmationContext,
      ref: ref,
      wallet: wallet,
      destination: destination,
      amount: amount,
      feeQuote: feeQuote,
      toAddress: toAddress,
      authResult: authResult,
      showSentTransactionNotification: showSentTransactionNotification,
      resolveRecentDestinationLabel: resolveRecentDestinationLabel,
      isMounted: isMounted,
    );
  }

  if (destination.isExternal) {
    return _confirmExternalSend(
      context: context,
      confirmationContext: confirmationContext,
      ref: ref,
      wallet: wallet,
      destination: destination,
      amount: amount,
      feeQuote: feeQuote,
      toAddress: toAddress,
      authResult: authResult,
      showSentTransactionNotification: showSentTransactionNotification,
      resolveRecentDestinationLabel: resolveRecentDestinationLabel,
      isMounted: isMounted,
    );
  }

  return _confirmInternalSend(
    confirmationContext: confirmationContext,
    ref: ref,
    wallet: wallet,
    destination: destination,
    amount: amount,
    feeQuote: feeQuote,
    toAddress: toAddress,
    authResult: authResult,
    showSentTransactionNotification: showSentTransactionNotification,
    resolveRecentDestinationLabel: resolveRecentDestinationLabel,
    resolveRecentDestinationAddress: resolveRecentDestinationAddress,
    isMounted: isMounted,
  );
}

Future<dynamic> _confirmPaymentLink({
  required BuildContext confirmationContext,
  required WidgetRef ref,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double amount,
  required String toAddress,
  required String linkId,
  required TransactionAuthResult authResult,
  required Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification,
  required bool Function() isMounted,
}) async {
  final result = await ref.read(paymentLinkNotifierProvider.notifier).pay(
        linkId: linkId,
        payerWalletId: wallet.id,
        totpCode: authResult.totpCode,
        confirmationPassphrase: authResult.confirmationPassphrase,
        passkeyAssertionJson: authResult.passkeyAssertionJson,
        appPin: authResult.appPin,
      );

  if (result != null) {
    await showSentTransactionNotification(
      wallet: wallet,
      destination: destination,
      amount: amount,
      toAddress: toAddress,
    );
    HapticFeedback.vibrate();
    ref.read(paymentLinkNotifierProvider.notifier).reset();
    return result;
  }

  final error = ref.read(paymentLinkNotifierProvider).error;
  // Silent when user cancelled passkey/device-key (error cleared in notifier).
  if (error != null) {
    HapticFeedback.heavyImpact();
    if (!isMounted() || !confirmationContext.mounted) return null;
    DeviceCredentialErrorUx.showNoticeIfDeviceCredential(
      error,
      l10n: confirmationContext.l10n,
    );
  }
  ref.read(paymentLinkNotifierProvider.notifier).reset();
  return null;
}

Future<dynamic> _confirmColdSend({
  required BuildContext confirmationContext,
  required WidgetRef ref,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double amount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required TransactionAuthResult authResult,
  required Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification,
  required String? Function(String toAddress) resolveRecentDestinationLabel,
  required bool Function() isMounted,
}) async {
  if (!destination.isOnChain) {
    SnackbarHelper.showError(
      SendMoneyCopy.coldOnlyOnchain(confirmationContext),
    );
    return null;
  }

  final totp = authResult.totpCode?.trim() ?? '';
  if (totp.length < 6) {
    SnackbarHelper.showError(
      'É necessário o código do autenticador para autorizar o envio da cold.',
    );
    return null;
  }

  final amountSats = (amount * 100000000).round();
  if (amountSats < 546) {
    SnackbarHelper.showError('Valor mínimo on-chain é 546 sats.');
    return null;
  }

  final feeRate = feeQuote.feeRateSatPerByte;
  final feeRateInt =
      feeRate != null && feeRate > 0 ? feeRate.round() : null;

  final networkKind = inferBitcoinNetworkFromAddress(toAddress);
  final signingNetwork = switch (networkKind) {
    BitcoinNetworkKind.mainnet => BitcoinNetwork.mainnet,
    BitcoinNetworkKind.regtest => BitcoinNetwork.testnet,
    _ => BitcoinNetwork.testnet,
  };

  try {
    final coordinator = ColdWalletSpendCoordinator(
      accountsService: ref.read(bitcoinAccountsServiceProvider),
    );
    final result = await coordinator.spend(
      coldWalletId: wallet.id.trim(),
      destinationAddress: toAddress,
      amountSats: amountSats,
      totpCode: totp,
      feeRateSatsPerVbyte: feeRateInt,
      network: signingNetwork,
      broadcast: true,
    );

    await ref
        .read(recentTransactionDestinationsProvider.notifier)
        .saveDestination(
          address: toAddress,
          kind: RecentTransactionDestinationKind.onChain,
          label: resolveRecentDestinationLabel(toAddress),
        );
    await showSentTransactionNotification(
      wallet: wallet,
      destination: destination,
      amount: amount,
      toAddress: toAddress,
    );
    HapticFeedback.vibrate();

    final txid = result.txid?.trim() ?? '';
    final networkFeeSats = (feeQuote.networkFeeBtc * 100000000).round();
    return TxStatus(
      txid: txid.isNotEmpty ? txid : (result.workflow.id),
      status: txid.isNotEmpty ? 'broadcasted' : result.workflow.status,
      feeSatoshis: networkFeeSats,
      amountReceived: amount,
      networkFeeBtc: feeQuote.networkFeeBtc,
      platformFeeBtc: 0,
      totalDebitedBtc: feeQuote.totalDebitedBtc > 0
          ? feeQuote.totalDebitedBtc
          : amount + feeQuote.networkFeeBtc,
      sender: wallet.address,
      receiver: toAddress,
      message: 'Assinado no aparelho',
    );
  } catch (error) {
    HapticFeedback.heavyImpact();
    if (!isMounted() || !confirmationContext.mounted) return null;
    SnackbarHelper.showError(
      ErrorTranslator.translate(confirmationContext.l10n, error.toString()),
    );
    return null;
  }
}

Future<dynamic> _confirmExternalSend({
  required BuildContext context,
  required BuildContext confirmationContext,
  required WidgetRef ref,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double amount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required TransactionAuthResult authResult,
  required Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification,
  required String? Function(String toAddress) resolveRecentDestinationLabel,
  required bool Function() isMounted,
}) async {
  final feeRate = feeQuote.feeRateSatPerByte;
  final feeRateInt =
      feeRate != null && feeRate > 0 ? feeRate.round() : null;
  final result = await ref.read(withdrawProvider.notifier).withdraw(
        fromWalletName: wallet.id,
        toAddress: destination.isOnChain ? toAddress : null,
        paymentRequest: destination.isLightning ? toAddress : null,
        amount: amount,
        totpCode: authResult.totpCode,
        isLightning: destination.isLightning,
        networkFeeBtc: feeQuote.networkFeeBtc,
        maxRoutingFeeBtc: defaultLightningRoutingFeeBtc,
        feeRateSatPerVbyte: destination.isOnChain ? feeRateInt : null,
        feeTargetBlocks:
            destination.isOnChain ? feeQuote.feeTargetBlocks : null,
        description: destination.isLightning
            ? 'Pagamento Lightning'
            : SendMoneyCopy.onchainSendDescription(context),
        confirmationPassphrase: authResult.confirmationPassphrase,
        passkeyAssertionJson: authResult.passkeyAssertionJson,
        appPin: authResult.appPin,
      );

  if (result != null) {
    await ref
        .read(recentTransactionDestinationsProvider.notifier)
        .saveDestination(
          address: toAddress,
          kind: destination.isLightning
              ? RecentTransactionDestinationKind.lightning
              : RecentTransactionDestinationKind.onChain,
          label: resolveRecentDestinationLabel(toAddress),
        );
    await showSentTransactionNotification(
      wallet: wallet,
      destination: destination,
      amount: amount,
      toAddress: toAddress,
    );
    HapticFeedback.vibrate();
    ref.read(withdrawProvider.notifier).reset();
    return result;
  }

  final error = ref.read(withdrawProvider).error;
  if (error != null) {
    HapticFeedback.heavyImpact();
    if (!isMounted() || !confirmationContext.mounted) return null;
    DeviceCredentialErrorUx.showNoticeIfDeviceCredential(
      error,
      l10n: confirmationContext.l10n,
    );
  }
  ref.read(withdrawProvider.notifier).reset();
  return null;
}

Future<dynamic> _confirmInternalSend({
  required BuildContext confirmationContext,
  required WidgetRef ref,
  required Wallet wallet,
  required SendDestinationAnalysis destination,
  required double amount,
  required SendFeeQuote feeQuote,
  required String toAddress,
  required TransactionAuthResult authResult,
  required Future<void> Function({
    required Wallet wallet,
    required SendDestinationAnalysis destination,
    required double amount,
    required String toAddress,
  }) showSentTransactionNotification,
  required String? Function(String toAddress) resolveRecentDestinationLabel,
  required String Function(String toAddress) resolveRecentDestinationAddress,
  required bool Function() isMounted,
}) async {
  final idempotencyKey = const Uuid().v4();
  final result = await ref.read(sendTransactionProvider.notifier).send(
        fromWalletId: wallet.id,
        fromAddress:
            wallet.address.trim().isEmpty ? null : wallet.address.trim(),
        toAddress: toAddress,
        amount: amount,
        feeSatoshis: (feeQuote.networkFeeBtc * 100000000).toInt(),
        context: null,
        passkeyAssertionJson: authResult.passkeyAssertionJson,
        confirmationPassphrase: authResult.confirmationPassphrase,
        totpCode: authResult.totpCode,
        idempotencyKey: idempotencyKey,
        requestTimestamp: DateTime.now().millisecondsSinceEpoch,
        appPin: authResult.appPin,
      );

  if (result != null) {
    await ref
        .read(recentTransactionDestinationsProvider.notifier)
        .saveDestination(
          address: resolveRecentDestinationAddress(toAddress),
          kind: RecentTransactionDestinationKind.internal,
          label: resolveRecentDestinationLabel(toAddress),
        );
    await showSentTransactionNotification(
      wallet: wallet,
      destination: destination,
      amount: amount,
      toAddress: toAddress,
    );
    HapticFeedback.vibrate();
    ref.read(sendTransactionProvider.notifier).reset();
    return result;
  }

  final error = ref.read(sendTransactionProvider).error;
  if (error != null) {
    HapticFeedback.heavyImpact();
    if (!isMounted() || !confirmationContext.mounted) return null;
    DeviceCredentialErrorUx.showNoticeIfDeviceCredential(
      error,
      l10n: confirmationContext.l10n,
    );
  }
  ref.read(sendTransactionProvider.notifier).reset();
  return null;
}
