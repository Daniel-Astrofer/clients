import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/design_system/icons.dart';
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

    if (isDone) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: AppColors.hexFF141517, // homeCardColor
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, '/onboarding/steps');
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.hexFF2A2A2A, // homePanelBorderColor
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _SegmentedPieChartContainer(completedSteps: completed),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDone ? 'Ativação Concluída' : 'Ativação da Conta',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDone
                            ? 'Sua conta está totalmente ativa.'
                            : 'Complete $completed de 3 etapas essenciais.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  KeroseneIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.35),
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
              activeColor: isDone ? AppColors.hexFF4ADE80 : Colors.white,
              inactiveColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: isDone
                ? const Icon(
                    KeroseneIcons.success,
                    color: AppColors.hexFF4ADE80,
                    size: 16,
                  )
                : Text(
                    '$completedSteps/3',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: AppTypography.financialFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

    double startAngle = -math.pi / 2 + gapAngle / 2; // start from top (12 o'clock)

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
