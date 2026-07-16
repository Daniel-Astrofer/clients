import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live playback state for ephemeral home greeting (driven by HomeGreetingSlot).
class HomeGreetingPlayback {
  /// True while a market line is on screen (once or loop).
  final bool isPlaying;

  /// Hide header icon buttons for this frame.
  final bool hideActions;

  /// Extra space above the balance card / status while playing.
  final double pushDownBalancePx;

  /// Slightly tighter gaps under the greeting while playing.
  final bool compressLayout;

  const HomeGreetingPlayback({
    this.isPlaying = false,
    this.hideActions = false,
    this.pushDownBalancePx = 0,
    this.compressLayout = false,
  });

  static const idle = HomeGreetingPlayback();

  HomeGreetingPlayback copyWith({
    bool? isPlaying,
    bool? hideActions,
    double? pushDownBalancePx,
    bool? compressLayout,
  }) {
    return HomeGreetingPlayback(
      isPlaying: isPlaying ?? this.isPlaying,
      hideActions: hideActions ?? this.hideActions,
      pushDownBalancePx: pushDownBalancePx ?? this.pushDownBalancePx,
      compressLayout: compressLayout ?? this.compressLayout,
    );
  }
}

class HomeGreetingPlaybackNotifier extends Notifier<HomeGreetingPlayback> {
  @override
  HomeGreetingPlayback build() => HomeGreetingPlayback.idle;

  void setPlaying({
    required bool hideActions,
    required double pushDownBalancePx,
    required bool compressLayout,
  }) {
    state = HomeGreetingPlayback(
      isPlaying: true,
      hideActions: hideActions,
      pushDownBalancePx: pushDownBalancePx,
      compressLayout: compressLayout,
    );
  }

  void setIdle() {
    if (state.isPlaying ||
        state.hideActions ||
        state.pushDownBalancePx > 0 ||
        state.compressLayout) {
      state = HomeGreetingPlayback.idle;
    }
  }
}

final homeGreetingPlaybackProvider =
    NotifierProvider<HomeGreetingPlaybackNotifier, HomeGreetingPlayback>(
  HomeGreetingPlaybackNotifier.new,
);
