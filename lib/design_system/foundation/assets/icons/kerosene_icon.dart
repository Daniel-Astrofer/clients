import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_ui_scale.dart';

/// Standard icon with shared client presentation density.
/// Retains its original layout, hit target, color and semantic contract.
class KeroseneIcon extends Icon {
  const KeroseneIcon(
    super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    super.applyTextScaling,
    super.blendMode,
    super.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final followsText =
        applyTextScaling ?? IconTheme.of(context).applyTextScaling ?? false;
    if (scaler is KeroseneTextScaler && followsText) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler.inherited),
        child: Builder(
            builder: (inner) =>
                KeroseneUiScale.icon(context, super.build(inner))),
      );
    }
    return KeroseneUiScale.icon(context, super.build(context));
  }
}
