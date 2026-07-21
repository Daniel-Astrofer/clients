import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/handlers/gateway/gateway_handler.dart';
import 'package:kerosene/features/movement/handlers/internal/internal_handler.dart';
import 'package:kerosene/features/movement/handlers/lightning/lightning_handler.dart';
import 'package:kerosene/features/movement/handlers/nfc/nfc_handler.dart';
import 'package:kerosene/features/movement/handlers/onchain/onchain_handler.dart';
import 'package:kerosene/features/movement/handlers/payment_link/payment_link_handler.dart';
import 'package:kerosene/features/movement/kernel/execution/movement_handler.dart';
import 'package:kerosene/features/movement/kernel/execution/send_rail_handlers.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_router.dart';

/// Receive / hub entries (UI tiles). Separate from send rail handlers.
final movementEntryProvidersRegistry =
    Provider<List<MovementEntryProvider>>((ref) {
  return [
    const GatewayMovementProvider(),
    const InternalMovementProvider(),
    const LightningMovementProvider(),
    const OnchainMovementProvider(),
    const PaymentLinkMovementProvider(),
    const NfcMovementProvider(),
  ];
});

/// Send rail handlers — most specific first.
final movementHandlerRegistryProvider = Provider<List<MovementHandler>>((ref) {
  return const [
    PaymentLinkMovementHandler(),
    LightningMovementHandler(),
    OnchainMovementHandler(),
    InternalMovementHandler(),
  ];
});

final movementRouterProvider = Provider<MovementRouter>((ref) {
  return MovementRouter(ref.watch(movementHandlerRegistryProvider));
});
