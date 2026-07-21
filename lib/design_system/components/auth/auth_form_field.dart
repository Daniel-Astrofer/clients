import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// Labeled auth form field — shared chrome for login / signup / recovery.
///
/// Prefer this over one-off [TextField] decorations in auth screens.
class AuthFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final bool uppercaseLabel;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? labelColor;
  final Color? cursorColor;
  final TextStyle? labelStyle;
  final TextStyle? fieldStyle;
  final BorderRadius? borderRadius;
  final bool useFloatingLabel;

  const AuthFormField({
    super.key,
    this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.uppercaseLabel = false,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.textColor,
    this.hintColor,
    this.labelColor,
    this.cursorColor,
    this.labelStyle,
    this.fieldStyle,
    this.borderRadius,
    this.useFloatingLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppRadius.input;
    final resolvedText = textColor ?? theme.colorScheme.onSurface;
    final resolvedHint = hintColor ?? resolvedText.withValues(alpha: 0.36);
    final resolvedBorder = borderColor ?? theme.dividerColor;
    final resolvedFocus =
        focusedBorderColor ?? resolvedText.withValues(alpha: 0.45);
    final resolvedFill = fillColor ?? theme.colorScheme.surfaceContainerHighest;

    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: resolvedBorder),
    );

    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      autofocus: autofocus,
      enabled: enabled,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      cursorColor: cursorColor ?? resolvedText,
      style: (fieldStyle ?? AppTypography.bodyLarge).copyWith(
        color: enabled ? resolvedText : resolvedText.withValues(alpha: 0.48),
      ),
      decoration: InputDecoration(
        labelText: useFloatingLabel ? label : null,
        hintText: hint,
        hintStyle: (fieldStyle ?? AppTypography.bodyMedium).copyWith(
          color: resolvedHint,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: enabled ? resolvedFill : resolvedFill.withValues(alpha: 0.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: BorderSide(
            color: resolvedBorder.withValues(alpha: 0.72),
          ),
        ),
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: resolvedFocus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
        ),
      ),
    );

    if (useFloatingLabel) return field;

    final resolvedLabelStyle = labelStyle ??
        AppTypography.bodyMedium.copyWith(
          color: labelColor ?? resolvedText,
          fontWeight: FontWeight.w600,
          letterSpacing: uppercaseLabel ? 0 : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          uppercaseLabel ? label.toUpperCase() : label,
          style: resolvedLabelStyle,
        ),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }
}
