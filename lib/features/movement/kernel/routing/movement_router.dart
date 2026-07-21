import 'package:kerosene/features/movement/kernel/execution/movement_handler.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';

class MovementRouter {
  final List<MovementHandler> _handlers;

  const MovementRouter(this._handlers);

  MovementHandler? findHandler(MovementIntent intent, MovementCapability caps) {
    for (final handler in _handlers) {
      if (handler.canHandle(intent, caps)) return handler;
    }
    return null;
  }
}
