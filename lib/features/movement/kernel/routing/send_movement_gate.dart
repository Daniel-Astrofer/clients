import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/execution/movement_handler.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent_bridge.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_route.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_router.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

/// Result of asking the kernel which send handler owns a destination.
class SendMovementDecision {
  final MovementHandler? handler;
  final MovementRoute? route;
  final String? errorMessage;

  const SendMovementDecision({
    this.handler,
    this.route,
    this.errorMessage,
  });

  bool get canContinue =>
      handler != null && route != null && route!.canContinue && errorMessage == null;

  List<String> get blockers => route?.blockers ?? const [];

  ResolvedPaymentIntent? get resolvedIntent {
    final extra = route?.extraArgs;
    return extra is ResolvedPaymentIntent ? extra : null;
  }
}

/// Thin shell API: destination + source → handler route.
Future<SendMovementDecision> decideSendMovement({
  required MovementRouter router,
  required SendDestinationAnalysis destination,
  Wallet? sourceWallet,
  KfeReceivingCapabilities? receiverCapabilities,
  Set<String> eligibleSourceWalletIds = const {},
  BitcoinNetworkKind expectedNetwork = BitcoinNetworkKind.unknown,
  PaymentRail? userSelectedRail,
}) async {
  if (destination.isEmpty) {
    return const SendMovementDecision(
      errorMessage: 'Informe um destino para continuar.',
    );
  }
  if (destination.isInvalid) {
    return const SendMovementDecision(
      errorMessage: 'Destino não reconhecido.',
    );
  }

  final intent = movementIntentFromDestination(destination);
  final caps = MovementCapability(
    wallet: sourceWallet,
    sourceCustody: PaymentIntentResolver.instance.classifySource(sourceWallet),
    receiverCapabilities: receiverCapabilities,
    eligibleSourceWalletIds: eligibleSourceWalletIds,
    expectedNetwork: expectedNetwork,
    userSelectedRail: userSelectedRail,
  );

  final handler = router.findHandler(intent, caps);
  if (handler == null) {
    return const SendMovementDecision(
      errorMessage: 'Nenhum caminho de envio disponível para este destino.',
    );
  }

  final route = await handler.resolve(intent, caps);
  return SendMovementDecision(handler: handler, route: route);
}
