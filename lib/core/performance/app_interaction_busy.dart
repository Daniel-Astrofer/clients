import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while a [PageRoute] push/pop/replace animation is running.
///
/// Consumers (aurora clock, ambient shaders) freeze GPU loops during
/// transitions so first paint of the destination keeps raster budget.
final routeTransitionBusyProvider =
    NotifierProvider<RouteTransitionBusyNotifier, bool>(
  RouteTransitionBusyNotifier.new,
);

class RouteTransitionBusyNotifier extends Notifier<bool> {
  int _depth = 0;

  @override
  bool build() => false;

  void begin() {
    _depth += 1;
    if (!state) state = true;
  }

  void end() {
    if (_depth > 0) _depth -= 1;
    if (_depth == 0 && state) state = false;
  }

  void setBusy(bool busy) {
    if (busy) {
      begin();
    } else {
      end();
    }
  }
}
