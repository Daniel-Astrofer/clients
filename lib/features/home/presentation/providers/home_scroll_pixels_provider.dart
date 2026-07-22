import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Positive vertical scroll offset of the home [CustomScrollView] (px).
/// Used so the single aurora can travel with the balance on downward scroll.
final homeScrollPixelsProvider =
    NotifierProvider<HomeScrollPixelsNotifier, double>(
  HomeScrollPixelsNotifier.new,
);

class HomeScrollPixelsNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  @override
  set state(double value) {
    if (super.state == value) return;
    super.state = value;
  }
}
