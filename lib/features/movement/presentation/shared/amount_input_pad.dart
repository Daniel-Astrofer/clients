import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

class AmountInputPad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onBackspace;
  final VoidCallback onDecimal;

  const AmountInputPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspace,
    required this.onDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      decoration: BoxDecoration(
        color:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
        border: Border.all(color: ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              _buildKey(context, '1'),
              _buildKey(context, '2'),
              _buildKey(context, '3'),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildKey(context, '4'),
              _buildKey(context, '5'),
              _buildKey(context, '6'),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildKey(context, '7'),
              _buildKey(context, '8'),
              _buildKey(context, '9'),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildKey(context, '.'),
              _buildKey(context, '0'),
              _buildActionKey(context, KeroseneIcons.backspace, onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(BuildContext context, String value) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (value == '.') {
              onDecimal();
            } else {
              onNumberPressed(value);
            }
          },
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: ink.withValues(alpha: 0.08)),
            ),
            child: Text(
              value,
              style: AppTypography.h3.copyWith(
                color: ink,
                fontWeight: FontWeight.w300,
                fontFamily: AppTypography.financialFontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(
      BuildContext context, IconData icon, VoidCallback onTap) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: ink.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: ink, size: 20),
          ),
        ),
      ),
    );
  }
}
