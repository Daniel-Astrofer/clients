import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the vertical overscroll in pixels (negative scroll).
/// Used to drive reactive atmospheric effects like the aurora glow during pull-to-refresh.
final homeOverscrollProvider = NotifierProvider<HomeOverscrollNotifier, double>(
  HomeOverscrollNotifier.new,
);

class HomeOverscrollNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  @override
  set state(double value) {
    if (super.state == value) return;
    super.state = value;
  }
}
