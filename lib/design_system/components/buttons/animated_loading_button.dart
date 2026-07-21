import 'package:flutter/material.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';

/// Loading-aware primary button — thin wrapper over [AppButton].
class AnimatedLoadingButton extends StatelessWidget {
  const AnimatedLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final bool expand;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      icon: icon,
      expand: expand,
      variant: variant,
    );
  }
}
