import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Real-time frame budget auditor targeting 240 FPS (4.166 ms per frame).
///
/// In 240 FPS rendering, total frame budget is 4,166 µs:
/// - UI Build phase (CPU): <= 2,083 µs (2.08 ms)
/// - Raster phase (GPU):   <= 2,083 µs (2.08 ms)
class FrameBudgetMonitor240Hz {
  static const int totalBudgetMicros = 4166;
  static const int halfPhaseBudgetMicros = 2083;

  static bool _attached = false;
  static int totalFrames = 0;
  static int jankFrames = 0;
  static int cpuSpikes = 0;
  static int gpuSpikes = 0;

  static void attach() {
    if (_attached || !kDebugMode && !kProfileMode) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void detach() {
    if (!_attached) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _attached = false;
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming frame in timings) {
      totalFrames++;
      final int buildUs = frame.buildDuration.inMicroseconds;
      final int rasterUs = frame.rasterDuration.inMicroseconds;
      final int totalUs = frame.totalSpan.inMicroseconds;

      bool isJank = false;
      if (buildUs > halfPhaseBudgetMicros) {
        cpuSpikes++;
        isJank = true;
      }
      if (rasterUs > halfPhaseBudgetMicros) {
        gpuSpikes++;
        isJank = true;
      }
      if (totalUs > totalBudgetMicros) {
        isJank = true;
      }

      if (isJank) {
        jankFrames++;
        if (kDebugMode) {
          debugPrint(
            '[240FPS JANK] Frame exceeded 4.16ms budget! '
            'UI Build: ${(buildUs / 1000).toStringAsFixed(2)}ms | '
            'GPU Raster: ${(rasterUs / 1000).toStringAsFixed(2)}ms | '
            'Total: ${(totalUs / 1000).toStringAsFixed(2)}ms (Jank Rate: ${((jankFrames / totalFrames) * 100).toStringAsFixed(1)}%)',
          );
        }
      }
    }
  }

  /// Reset telemetry stats.
  static void reset() {
    totalFrames = 0;
    jankFrames = 0;
    cpuSpikes = 0;
    gpuSpikes = 0;
  }
}
