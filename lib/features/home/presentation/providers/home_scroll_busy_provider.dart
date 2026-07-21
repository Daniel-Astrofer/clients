import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the home [CustomScrollView] is actively scrolling.
///
/// Ambient layers pause heavy tickers so scroll can hold 120 Hz.
final homeScrollBusyProvider = NotifierProvider<HomeScrollBusyNotifier, bool>(
  HomeScrollBusyNotifier.new,
);

class HomeScrollBusyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setBusy(bool busy) {
    if (state == busy) return;
    state = busy;
  }
}
