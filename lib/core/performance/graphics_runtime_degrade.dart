import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Budget for build+raster at 60Hz (microseconds). Sustained overrun
/// triggers temporary quality drop without changing layout/design.
const int kGraphicsJankBudgetUs = 16670;

/// Consecutive over-budget frames before entering degrade mode.
const int kGraphicsJankTriggerStreak = 12;

/// Consecutive good frames before leaving degrade mode (~1.5s @ 60Hz).
const int kGraphicsRecoverGoodStreak = 90;

/// True while runtime FrameTiming reports sustained jank.
///
/// When true, [graphicsPolicyProvider] clears blur / ambient GPU loops.
/// Recovers automatically after a stretch of healthy frames.
final graphicsRuntimeDegradeProvider =
    NotifierProvider<GraphicsRuntimeDegradeNotifier, bool>(
  GraphicsRuntimeDegradeNotifier.new,
);

class GraphicsRuntimeDegradeNotifier extends Notifier<bool> {
  int _jankStreak = 0;
  int _goodStreak = 0;
  bool _listening = false;

  @override
  bool build() {
    ref.onDispose(_stop);
    // Defer so SchedulerBinding is fully ready after runApp.
    Future<void>.microtask(start);
    return false;
  }

  void start() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _stop() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final costUs = timing.buildDuration.inMicroseconds +
          timing.rasterDuration.inMicroseconds;
      if (costUs > kGraphicsJankBudgetUs) {
        _jankStreak += 1;
        _goodStreak = 0;
        if (!state && _jankStreak >= kGraphicsJankTriggerStreak) {
          state = true;
          _jankStreak = 0;
          if (kDebugMode) {
            debugPrint(
              '[graphics] runtime degrade ON '
              '(build+raster ${costUs ~/ 1000}ms)',
            );
          }
        }
      } else {
        _jankStreak = 0;
        _goodStreak += 1;
        if (state && _goodStreak >= kGraphicsRecoverGoodStreak) {
          state = false;
          _goodStreak = 0;
          if (kDebugMode) {
            debugPrint('[graphics] runtime degrade OFF (stable frames)');
          }
        }
      }
    }
  }

  /// Force-clear (tests / debug).
  void reset() {
    _jankStreak = 0;
    _goodStreak = 0;
    if (state) state = false;
  }
}
