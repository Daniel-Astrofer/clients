import 'package:flutter/material.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';

/// The primary action cluster — Send (dominant) + Receive (secondary).
///
/// Send is the outlined pill (primary), Receive is ghost (secondary).
/// This is the canonical action pattern for the home screen.
///
/// Usage:
/// ```dart
/// KerosenePrimaryActionCluster(
///   onSend: () => context.push('/send'),
///   onReceive: () => context.push('/receive'),
/// )
/// ```
class KerosenePrimaryActionCluster extends StatelessWidget {
  final VoidCallback? onSend;
  final VoidCallback? onReceive;
  final VoidCallback? onScan;
  final String sendLabel;
  final String receiveLabel;

  const KerosenePrimaryActionCluster({
    super.key,
    this.onSend,
    this.onReceive,
    this.onScan,
    this.sendLabel = 'Enviar',
    this.receiveLabel = 'Receber',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: Send (outlined pill)
        AppButton(
          label: sendLabel,
          onPressed: onSend,
          variant: AppButtonVariant.primary,
        ),
        SizedBox(width: AppSpacing.base),
        // Secondary: Receive (ghost)
        AppButton(
          label: receiveLabel,
          onPressed: onReceive,
          variant: AppButtonVariant.ghost,
        ),
        if (onScan != null) ...[
          SizedBox(width: AppSpacing.base),
          AppButton(
            label: 'QR',
            onPressed: onScan,
            variant: AppButtonVariant.ghost,
          ),
        ],
      ],
    );
  }
}
