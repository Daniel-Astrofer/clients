import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';

/// Live theater playback: whether a stage piece is showing and body offset.
class HomeStagePlayback {
  final bool isPlaying;
  final HomeStageActionsPlacement actionsPlacement;
  final double bodyOffsetPx;
  final int bodyShiftDurationMs;
  final HomeStageCurveToken bodyShiftCurve;
  final String stageId;

  const HomeStagePlayback({
    this.isPlaying = false,
    this.actionsPlacement = HomeStageActionsPlacement.trailing,
    this.bodyOffsetPx = 0,
    this.bodyShiftDurationMs = 480,
    this.bodyShiftCurve = HomeStageCurveToken.easeOutCubic,
    this.stageId = '',
  });

  static const idle = HomeStagePlayback();
}

class HomeStagePlaybackNotifier extends Notifier<HomeStagePlayback> {
  @override
  HomeStagePlayback build() => HomeStagePlayback.idle;

  void play(HomeStage stage) {
    if (!stage.isActive) {
      clear();
      return;
    }
    final placement = stage.layout.actions.resolvePlacement(stage.media);
    final shift = stage.motion.bodyShift;
    state = HomeStagePlayback(
      isPlaying: true,
      actionsPlacement: placement,
      bodyOffsetPx: shift.enabled ? shift.offsetPx : 0,
      bodyShiftDurationMs: shift.durationMs,
      bodyShiftCurve: shift.curve,
      stageId: stage.id,
    );
  }

  void clear() {
    if (state.isPlaying || state.bodyOffsetPx > 0) {
      state = HomeStagePlayback(
        isPlaying: false,
        actionsPlacement: HomeStageActionsPlacement.trailing,
        bodyOffsetPx: 0,
        bodyShiftDurationMs: state.bodyShiftDurationMs,
        bodyShiftCurve: state.bodyShiftCurve,
        stageId: '',
      );
    }
  }
}

final homeStagePlaybackProvider =
    NotifierProvider<HomeStagePlaybackNotifier, HomeStagePlayback>(
  HomeStagePlaybackNotifier.new,
);
