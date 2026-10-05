import 'package:kerosene/core/navigation/app_navigation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import '../providers/onboarding_progress_provider.dart';

class HomeOnboardingProgressCard extends ConsumerWidget {
  const HomeOnboardingProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingProgressProvider);

    return _buildCard(context, progress);
  }

  Widget _buildCard(BuildContext context, OnboardingProgress progress) {
    final completed = progress.completedSteps;
    final isDone = progress.isAllCompleted;
    final surface = HomeSurfaceTheme.of(context);

    if (isDone) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: surface.card,
        borderRadius: BorderRadius.circular(HomeRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeRadius.card),
          onTap: () {
            HapticFeedback.selectionClick();
            AppNavigation.push(context, '/onboarding/steps');
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HomeRadius.card),
              border: Border.all(
                color: surface.surfaceBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _SegmentedPieChartContainer(completedSteps: completed),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.onboardingJourneyTitle,
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        context.tr.onboardingProgressCount(completed),
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  KeroseneIcons.chevronRight,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedPieChartContainer extends StatelessWidget {
  final int completedSteps;

  const _SegmentedPieChartContainer({required this.completedSteps});

  @override
  Widget build(BuildContext context) {
    final isDone = completedSteps == 3;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(44, 44),
            painter: _SegmentedPieChartPainter(
              completedSteps: completedSteps,
              totalSteps: 3,
              activeColor: isDone
                  ? AppColors.hexFF4ADE80
                  : Theme.of(context).colorScheme.onSurface,
              inactiveColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: isDone
                ? Icon(
                    KeroseneIcons.success,
                    color: AppColors.hexFF4ADE80,
                    size: 16,
                  )
                : Text(
                    '$completedSteps/3',
                    style: AppTypography.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedPieChartPainter extends CustomPainter {
  final int completedSteps;
  final int totalSteps;
  final Color activeColor;
  final Color inactiveColor;

  _SegmentedPieChartPainter({
    required this.completedSteps,
    required this.totalSteps,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    const double gapAngle = 0.15; // gap in radians (~8.6 degrees)
    final double totalGapAngle = gapAngle * totalSteps;
    final double segmentAngle = (2 * math.pi - totalGapAngle) / totalSteps;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    double startAngle =
        -math.pi / 2 + gapAngle / 2; // start from top (12 o'clock)

    for (int i = 0; i < totalSteps; i++) {
      paint.color = i < completedSteps ? activeColor : inactiveColor;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - paint.strokeWidth / 2),
        startAngle,
        segmentAngle,
        false,
        paint,
      );

      startAngle += segmentAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedPieChartPainter oldDelegate) {
    return oldDelegate.completedSteps != completedSteps ||
        oldDelegate.totalSteps != totalSteps ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
