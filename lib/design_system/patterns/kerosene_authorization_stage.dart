import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
/// The canonical authorization stage — PIN entry wrapper with security styling.
///
/// Authorization is ALWAYS a distinct screen/sheet, never an inline dialog.
/// Background uses the Onyx canvas for security focus.
///
/// Usage:
/// ```dart
/// KeroseneAuthorizationStage(
///   title: 'Digite seu PIN',
///   pinLength: 6,
///   onComplete: (pin) => verifyPin(pin),
///   onCancel: () => context.pop(),
/// )
/// ```
class KeroseneAuthorizationStage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int pinLength;
  final ValueChanged<String>? onComplete;
  final VoidCallback? onCancel;
  final bool isVerifying;
  final String? errorMessage;

  const KeroseneAuthorizationStage({
    super.key,
    required this.title,
    this.subtitle,
    this.pinLength = 6,
    this.onComplete,
    this.onCancel,
    this.isVerifying = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    // Security context — Onyx background, no chrome
    return Container(
      color: AppColors.onyxCanvas,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.module),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cancel
              if (onCancel != null)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(onPressed: onCancel, child: Text('Cancelar')),
                ),

              Spacer(),

              // Title
              Text(title, style: AppTypography.inter(fontSize: 15, color: palette.textPrimary, fontWeight: AppTypography.w510), textAlign: TextAlign.center),
              if (subtitle != null) ...[
                SizedBox(height: AppSpacing.sm),
                Text(subtitle!, style: AppTypography.inter(fontSize: 13, color: palette.textSecondary), textAlign: TextAlign.center),
              ],

              SizedBox(height: AppSpacing.module),

              // PIN dots
              if (isVerifying)
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(palette.textSecondary)))
              else
                // Placeholder: real implementation would use a PIN input widget
                _PinPlaceholder(length: pinLength, palette: palette),

              // Error
              if (errorMessage != null) ...[
                SizedBox(height: AppSpacing.base),
                Text(errorMessage!, style: AppTypography.inter(fontSize: 13, color: KeroseneBrandTokens.error), textAlign: TextAlign.center),
              ],

              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPlaceholder extends StatelessWidget {
  final int length;
  final KeroseneBrandTheme palette;
  const _PinPlaceholder({required this.length, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.border, width: 1),
          ),
        ),
      )),
    );
  }
}
