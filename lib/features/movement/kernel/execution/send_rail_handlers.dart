import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/execution/movement_handler.dart';
import 'package:kerosene/features/movement/kernel/execution/send_contexts.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent_bridge.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_route.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_rail_executors.dart';

/// Shared resolve path: PaymentIntentResolver owns rail matrix; handlers only
/// claim an intent kind and surface blockers to the send shell.
MovementRoute resolveSendRailRoute({
  required String handlerId,
  required MovementIntent intent,
  required MovementCapability caps,
  required Set<PaymentRail> acceptedRails,
}) {
  final payment = paymentIntentFromMovement(intent);
  final source = caps.sourceCustody ??
      PaymentIntentResolver.instance.classifySource(caps.wallet);
  final resolver = PaymentIntentResolver.instance;

  final resolved = caps.receiverCapabilities != null
      ? resolver.resolveWithCapabilities(
          intent: payment,
          source: source,
          capabilities: caps.receiverCapabilities!,
          expectedNetwork: caps.expectedNetwork,
          userSelectedRail: caps.userSelectedRail,
          sourceWalletId: caps.wallet?.id,
          sourceWalletAddress: caps.wallet?.address,
        )
      : resolver.resolveLocal(
          intent: payment,
          source: source,
          expectedNetwork: caps.expectedNetwork,
          sourceWalletId: caps.wallet?.id,
          sourceWalletAddress: caps.wallet?.address,
        );

  final blockers = <String>[
    for (final b in resolved.blockers) b.message,
  ];

  if (resolved.canContinue && !acceptedRails.contains(resolved.selectedRail)) {
    blockers.add('Este destino não usa o caminho esperado para envio.');
  }

  if (caps.wallet != null &&
      caps.eligibleSourceWalletIds.isNotEmpty &&
      !caps.eligibleSourceWalletIds.contains(caps.wallet!.id)) {
    blockers.add(
      'Esta carteira não consegue financiar o destino escolhido.',
    );
  }

  return MovementRoute(
    handlerId: handlerId,
    routeName: 'send_details',
    blockers: blockers,
    extraArgs: resolved,
  );
}

class PaymentLinkMovementHandler implements MovementHandler {
  const PaymentLinkMovementHandler();

  @override
  String get id => 'payment_link';

  @override
  bool canHandle(MovementIntent intent, MovementCapability caps) {
    return intent.isPaymentLink;
  }

  @override
  Future<MovementRoute> resolve(
    MovementIntent intent,
    MovementCapability caps,
  ) async {
    return resolveSendRailRoute(
      handlerId: id,
      intent: intent,
      caps: caps,
      acceptedRails: const {PaymentRail.paymentLink},
    );
  }

  @override
  SendFeeQuote? quote(SendQuoteRequest request) {
    return SendFeeQuoting.passthrough(
      amountBtc: request.amountBtc,
      platformFeeRate: 0,
      feeTier: request.feeTier,
    );
  }

  @override
  Future<Object?> execute(SendExecuteContext context) {
    final linkId =
        context.pendingPaymentLinkId ?? context.destination.paymentLinkId ?? '';
    return executePaymentLinkSend(
      confirmationContext: context.confirmationContext,
      ref: context.ref,
      wallet: context.wallet,
      destination: context.destination,
      amount: context.amount,
      toAddress: context.toAddress,
      linkId: linkId,
      authResult: context.authResult,
      showSentTransactionNotification: context.showSentTransactionNotification,
      isMounted: context.isMounted,
    );
  }
}

class LightningMovementHandler implements MovementHandler {
  const LightningMovementHandler();

  @override
  String get id => 'lightning';

  @override
  bool canHandle(MovementIntent intent, MovementCapability caps) {
    return intent.isLightning;
  }

  @override
  Future<MovementRoute> resolve(
    MovementIntent intent,
    MovementCapability caps,
  ) async {
    return resolveSendRailRoute(
      handlerId: id,
      intent: intent,
      caps: caps,
      acceptedRails: const {PaymentRail.lightning, PaymentRail.paymentLink},
    );
  }

  @override
  SendFeeQuote? quote(SendQuoteRequest request) {
    if (request.isColdSource) {
      return SendFeeQuoting.passthrough(
        amountBtc: request.amountBtc,
        platformFeeRate: 0,
        feeTier: request.feeTier,
        error: 'cold_no_lightning',
      );
    }
    final platformFeeRate = request.wallet.withdrawalFeeRate;
    return SendFeeQuoting.lightning(
      amountBtc: request.amountBtc,
      platformFeeRate: platformFeeRate,
      feeTier: request.feeTier,
    );
  }

  @override
  Future<Object?> execute(SendExecuteContext context) {
    return executeExternalSend(
      context: context.context,
      confirmationContext: context.confirmationContext,
      ref: context.ref,
      wallet: context.wallet,
      destination: context.destination,
      amount: context.amount,
      feeQuote: context.feeQuote,
      toAddress: context.toAddress,
      authResult: context.authResult,
      showSentTransactionNotification: context.showSentTransactionNotification,
      resolveRecentDestinationLabel: context.resolveRecentDestinationLabel,
      isMounted: context.isMounted,
    );
  }
}

class OnchainMovementHandler implements MovementHandler {
  const OnchainMovementHandler();

  @override
  String get id => 'onchain';

  @override
  bool canHandle(MovementIntent intent, MovementCapability caps) {
    return intent.isOnchain;
  }

  @override
  Future<MovementRoute> resolve(
    MovementIntent intent,
    MovementCapability caps,
  ) async {
    return resolveSendRailRoute(
      handlerId: id,
      intent: intent,
      caps: caps,
      acceptedRails: const {PaymentRail.onchain, PaymentRail.coldOnchain},
    );
  }

  @override
  SendFeeQuote? quote(SendQuoteRequest request) {
    final platformFeeRate =
        request.isColdSource ? 0.0 : request.wallet.withdrawalFeeRate;
    return SendFeeQuoting.fromEstimateAsync(
      request: request,
      platformFeeRate: platformFeeRate,
    );
  }

  @override
  Future<Object?> execute(SendExecuteContext context) {
    if (context.isColdSource) {
      return executeColdOnchainSend(
        confirmationContext: context.confirmationContext,
        ref: context.ref,
        wallet: context.wallet,
        destination: context.destination,
        amount: context.amount,
        feeQuote: context.feeQuote,
        toAddress: context.toAddress,
        authResult: context.authResult,
        showSentTransactionNotification:
            context.showSentTransactionNotification,
        resolveRecentDestinationLabel: context.resolveRecentDestinationLabel,
        isMounted: context.isMounted,
      );
    }
    return executeExternalSend(
      context: context.context,
      confirmationContext: context.confirmationContext,
      ref: context.ref,
      wallet: context.wallet,
      destination: context.destination,
      amount: context.amount,
      feeQuote: context.feeQuote,
      toAddress: context.toAddress,
      authResult: context.authResult,
      showSentTransactionNotification: context.showSentTransactionNotification,
      resolveRecentDestinationLabel: context.resolveRecentDestinationLabel,
      isMounted: context.isMounted,
    );
  }
}

class InternalMovementHandler implements MovementHandler {
  const InternalMovementHandler();

  @override
  String get id => 'internal';

  @override
  bool canHandle(MovementIntent intent, MovementCapability caps) {
    return intent.isInternal || intent.kind == MovementIntentKind.opaque;
  }

  @override
  Future<MovementRoute> resolve(
    MovementIntent intent,
    MovementCapability caps,
  ) async {
    return resolveSendRailRoute(
      handlerId: id,
      intent: intent,
      caps: caps,
      acceptedRails: const {
        PaymentRail.internal,
        PaymentRail.onchain,
        PaymentRail.lightning,
        PaymentRail.paymentLink,
      },
    );
  }

  @override
  SendFeeQuote? quote(SendQuoteRequest request) {
    return SendFeeQuoting.passthrough(
      amountBtc: request.amountBtc,
      platformFeeRate: request.wallet.withdrawalFeeRate,
      feeTier: request.feeTier,
    );
  }

  @override
  Future<Object?> execute(SendExecuteContext context) {
    return executeInternalSend(
      confirmationContext: context.confirmationContext,
      ref: context.ref,
      wallet: context.wallet,
      destination: context.destination,
      amount: context.amount,
      feeQuote: context.feeQuote,
      toAddress: context.toAddress,
      authResult: context.authResult,
      showSentTransactionNotification: context.showSentTransactionNotification,
      resolveRecentDestinationLabel: context.resolveRecentDestinationLabel,
      resolveRecentDestinationAddress: context.resolveRecentDestinationAddress,
      isMounted: context.isMounted,
    );
  }
}

/// Resolve which send handler should execute for the locked destination.
MovementHandler? sendHandlerForDestination({
  required List<MovementHandler> handlers,
  required SendDestinationAnalysis destination,
  required MovementCapability caps,
  String? pendingPaymentLinkId,
}) {
  if (pendingPaymentLinkId != null && pendingPaymentLinkId.trim().isNotEmpty) {
    for (final handler in handlers) {
      if (handler.id == 'payment_link') return handler;
    }
  }
  final intent = movementIntentFromDestination(destination);
  for (final handler in handlers) {
    if (handler.canHandle(intent, caps)) return handler;
  }
  return null;
}
