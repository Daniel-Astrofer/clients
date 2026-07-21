import 'dart:async';

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
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_spend_coordinator.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';

/// @Deprecated Prefer NetworkFeeCertainty.unknownUntilPay — kept for older call sites.
const defaultLightningRoutingFeeBtc = 0.000001;

Future<dynamic> executePaymentLinkSend({
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
    unawaited(
      showSentTransactionNotification(
        wallet: wallet,
        destination: destination,
        amount: amount,
        toAddress: toAddress,
      ),
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

Future<dynamic> executeColdOnchainSend({
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
  final feeRateInt = feeRate != null && feeRate > 0 ? feeRate.round() : null;

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

    unawaited(
      ref.read(recentTransactionDestinationsProvider.notifier).saveDestination(
            address: toAddress,
            kind: RecentTransactionDestinationKind.onChain,
            label: resolveRecentDestinationLabel(toAddress),
          ),
    );
    unawaited(
      showSentTransactionNotification(
        wallet: wallet,
        destination: destination,
        amount: amount,
        toAddress: toAddress,
      ),
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

Future<dynamic> executeExternalSend({
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
  final feeRateInt = feeRate != null && feeRate > 0 ? feeRate.round() : null;
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
    // Do not block the authorize UI on local bookkeeping / toast.
    unawaited(
      ref.read(recentTransactionDestinationsProvider.notifier).saveDestination(
            address: toAddress,
            kind: destination.isLightning
                ? RecentTransactionDestinationKind.lightning
                : RecentTransactionDestinationKind.onChain,
            label: resolveRecentDestinationLabel(toAddress),
          ),
    );
    unawaited(
      showSentTransactionNotification(
        wallet: wallet,
        destination: destination,
        amount: amount,
        toAddress: toAddress,
      ),
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

Future<dynamic> executeInternalSend({
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
    unawaited(
      ref.read(recentTransactionDestinationsProvider.notifier).saveDestination(
            address: resolveRecentDestinationAddress(toAddress),
            kind: RecentTransactionDestinationKind.internal,
            label: resolveRecentDestinationLabel(toAddress),
          ),
    );
    unawaited(
      showSentTransactionNotification(
        wallet: wallet,
        destination: destination,
        amount: amount,
        toAddress: toAddress,
      ),
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
