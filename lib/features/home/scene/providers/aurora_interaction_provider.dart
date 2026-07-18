import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeAuroraInteractionProvider = Provider<HomeAuroraInteractionController>(
  (ref) {
    final controller = HomeAuroraInteractionController();
    ref.onDispose(controller.dispose);
    return controller;
  },
);

/// Pointer + backend “stage energy” for the aurora shader.
///
/// Continuous repaint is owned by [SceneAuroraBackground]'s clock. This
/// controller only notifies when discrete interaction events change targets.
class HomeAuroraInteractionController extends ChangeNotifier {
  Offset _pointer = const Offset(0.5, 0.16);
  double _pointerEnergy = 0;

  /// Epoch ms of last backend/scene pulse (null = none).
  int? _pulseEpochMs;
  double _pulsePeak = 0;

  /// How long a scene pulse stays visible (ease-out).
  static const pulseDurationMs = 1600;

  Offset get pointer => _pointer;

  /// Instantaneous energy for painters — includes decaying scene pulse.
  double energyAt(DateTime now) {
    final pulse = _pulseAt(now);
    // Soft resting floor so the stage never feels completely dead after touch.
    final touch = math.max(_pointerEnergy, 0.08);
    return math.max(touch, pulse).clamp(0.0, 1.0);
  }

  /// Legacy accessor for call sites that cannot pass a clock.
  double get energy => energyAt(DateTime.now());

  void updatePointer(Offset localPosition, Size viewport) {
    if (viewport.isEmpty) return;
    final next = Offset(
      (localPosition.dx / viewport.width).clamp(0.0, 1.0),
      (localPosition.dy / viewport.height).clamp(0.0, 1.0),
    );
    if ((next - _pointer).distanceSquared < 0.000004 && _pointerEnergy >= 0.99) {
      return;
    }
    _pointer = next;
    _pointerEnergy = 1;
    notifyListeners();
  }

  void release() {
    if (_pointerEnergy <= 0.22) return;
    _pointerEnergy = 0.22;
    notifyListeners();
  }

  /// Backend / theater message arrived — surge intensity without rebuild storms.
  void pulseFromScene({double strength = 1.0}) {
    final peak = strength.clamp(0.35, 1.0);
    _pulseEpochMs = DateTime.now().millisecondsSinceEpoch;
    _pulsePeak = peak;
    // Nudge focus slightly so the light “leans” when news arrives.
    _pointer = Offset(
      (0.42 + 0.16 * peak).clamp(0.2, 0.8),
      (0.12 + 0.06 * peak).clamp(0.08, 0.28),
    );
    notifyListeners();
  }

  double _pulseAt(DateTime now) {
    final epoch = _pulseEpochMs;
    if (epoch == null || _pulsePeak <= 0) return 0;
    final elapsed = now.millisecondsSinceEpoch - epoch;
    if (elapsed < 0) return 0;
    if (elapsed >= pulseDurationMs) return 0;
    final t = elapsed / pulseDurationMs;
    // Fast attack, long soft release.
    final envelope = (1.0 - t) * (1.0 - t);
    return _pulsePeak * envelope;
  }
}
