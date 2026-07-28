import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/execution/send_contexts.dart';
import 'package:kerosene/features/movement/kernel/execution/send_rail_handlers.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_registry.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_execution_overlay.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';

export 'package:kerosene/features/movement/presentation/send/send_rail_executors.dart';

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
  MovementCapability? capability,
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

  final caps = capability ??
      MovementCapability(
        wallet: wallet,
        sourceCustody: PaymentIntentResolver.instance.classifySource(wallet),
        expectedNetwork: expectedBitcoinNetwork,
      );
  final handler = sendHandlerForDestination(
    handlers: ref.read(movementHandlerRegistryProvider),
    destination: destination,
    caps: caps,
    pendingPaymentLinkId: pendingPaymentLinkId,
  );
  if (handler == null) {
    SnackbarHelper.showError(SendMoneyCopy.unrecognizedDestination(context));
    return null;
  }

  if (handler.id == 'payment_link' && isColdSource) {
    SnackbarHelper.showError(
        SendMoneyCopy.coldNoPaymentLink(confirmationContext));
    return null;
  }

  return SendPaymentExecutionOverlay.show(
    confirmationContext,
    onExecute: () async {
      final result = await handler.execute(
        SendExecuteContext(
          context: context,
          confirmationContext: confirmationContext,
          ref: ref,
          wallet: wallet,
          destination: destination,
          amount: amount,
          feeQuote: feeQuote,
          toAddress: toAddress,
          pendingPaymentLinkId: pendingPaymentLinkId,
          authResult: authResult,
          showSentTransactionNotification: showSentTransactionNotification,
          resolveRecentDestinationLabel: resolveRecentDestinationLabel,
          resolveRecentDestinationAddress: resolveRecentDestinationAddress,
          isMounted: isMounted,
        ),
      );
      return result != null;
    },
  );
}
