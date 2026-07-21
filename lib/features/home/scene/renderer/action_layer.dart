import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeSize;
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/shared/widgets/bouncing_button_wrapper.dart';

typedef SceneActionHandler = void Function(String action);

/// CTA chip/button driven by [SceneCta]. Action routing stays in Flutter.
class SceneActionLayer extends StatelessWidget {
  final SceneCta cta;
  final SceneActionHandler? onAction;

  const SceneActionLayer({
    super.key,
    required this.cta,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (!cta.isActive) return const SizedBox.shrink();

    return BouncingButtonWrapper(
      onTap: () {
        HapticFeedback.selectionClick();
        onAction?.call(cta.action);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: homeSize(16),
          vertical: homeSize(10),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(homeSize(20)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.5,
          ),
        ),
        child: Text(
          cta.label,
          style: AppTypography.label.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
