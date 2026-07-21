import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/execution/send_contexts.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_route.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

/// Plugin contract for movement rails.
///
/// Receive hub entries stay on [MovementEntryProvider]. Send rails implement
/// [quote] / [execute] in addition to resolve.
abstract class MovementHandler {
  String get id;

  bool canHandle(MovementIntent intent, MovementCapability caps);

  Future<MovementRoute> resolve(MovementIntent intent, MovementCapability caps);

  /// Display / submit fee quote for this rail. Default: no quote support.
  SendFeeQuote? quote(SendQuoteRequest request) => null;

  /// Execute after shared auth gate. Default: unsupported.
  Future<Object?> execute(SendExecuteContext context) async => null;
}
