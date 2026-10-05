// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/components/auth/auth_form_field.dart';
import 'package:kerosene/design_system/components/auth/auth_primary_cta.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_motion.dart';
import 'package:qr_flutter/qr_flutter.dart';

Color get _signupInk => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.background
    : KeroseneBrandTheme.dark.background;
Color get _signupSurface => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.surface
    : KeroseneBrandTheme.dark.surface;
Color get _signupField => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.surfaceHigh
    : KeroseneBrandTheme.dark.surfaceElevated;
Color get _signupBorder => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.border
    : KeroseneBrandTheme.dark.border;
Color get _signupBorderSoft => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.border
    : KeroseneBrandTheme.dark.borderSubtle;
Color get _signupMuted => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.textSecondary
    : KeroseneBrandTheme.dark.textMuted;
Color get _signupDim => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.textMuted
    : KeroseneBrandTheme.dark.textMuted;
Color get _signupText => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.textPrimary
    : KeroseneBrandTheme.dark.textPrimary;

class SignupTypography {
  const SignupTypography._();

  static TextStyle title() {
    return AppTypography.newsreader(
      color: _signupText,
      fontSize: 32,
      fontWeight: FontWeight.w500,
      height: 1.08,
      letterSpacing: 0,
    );
  }

  static TextStyle subtitle() {
    return AppTypography.inter(
      color: _signupMuted,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
      letterSpacing: 0,
    );
  }

  static TextStyle label() {
    return AppTypography.inter(
      color: _signupText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  static TextStyle field() {
    return AppTypography.inter(
      color: _signupText,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  static TextStyle bodySmall({Color? color}) {
    return AppTypography.inter(
      color: color ?? _signupMuted,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
    );
  }

  static TextStyle bodyMedium({Color? color}) {
    return AppTypography.inter(
      color: color ?? _signupText,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
    );
  }

  static TextStyle sectionTitle() {
    return AppTypography.inter(
      color: _signupText,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  static TextStyle button({required Color color}) {
    return AppTypography.inter(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
    );
  }

  static TextStyle successTitle() {
    return AppTypography.newsreader(
      color: _signupText,
      fontSize: 31,
      fontWeight: FontWeight.w500,
      height: 1.08,
      letterSpacing: 0,
    );
  }

  static TextStyle successSubtitle() {
    return TextStyle(
      fontFamily: AppTypography.fontFamily,
      color: _signupMuted,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
    );
  }
}

class SignupTopBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  const SignupTopBar({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(KeroseneIcons.back, size: 24),
              color: _signupText.withValues(alpha: 0.86),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < totalSteps; index++) ...[
                if (index > 0) const SizedBox(width: 7),
                SizedBox(
                  width: 30,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AuthMotion.step,
                      curve: KeroseneMotion.standard,
                      width: index == step ? 30 : (index < step ? 18 : 8),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: index <= step
                            ? _signupText.withValues(
                                alpha: index == step ? 1 : 0.58,
                              )
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SignupStepColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const SignupStepColumn({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AuthMotionStagger(
      children: [
        Text(
          title,
          style: SignupTypography.title(),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: SignupTypography.subtitle(),
        ),
        const SizedBox(height: 34),
        ...children,
      ],
    );
  }
}

class SignupInlineFeedback extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const SignupInlineFeedback({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SignupPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SignupTypography.label().copyWith(
                    color: _signupText,
                    fontSize: 14,
                    height: 1.16,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: SignupTypography.bodySmall().copyWith(
                    color: _signupMuted,
                    height: 1.34,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SignupTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const SignupTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.autofocus = false,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AuthFormField(
      controller: controller,
      label: label,
      hint: hintText,
      obscureText: obscureText,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      suffixIcon: suffixIcon,
      fillColor: _signupField,
      borderColor: _signupBorder,
      focusedBorderColor:
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      textColor: _signupText,
      hintColor: _signupDim,
      cursorColor: _signupText,
      labelStyle: SignupTypography.label(),
      fieldStyle: SignupTypography.field(),
    );
  }
}

class SignupRuleRow extends StatelessWidget {
  final bool passed;
  final String text;

  const SignupRuleRow({required this.passed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? KeroseneIcons.success : KeroseneIcons.circle,
            size: 18,
            color: passed
                ? _signupText.withValues(alpha: 0.82)
                : _signupDim.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: SignupTypography.bodySmall(
                color:
                    passed ? _signupText.withValues(alpha: 0.82) : _signupMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignupRiskAcknowledgement extends StatelessWidget {
  final bool checked;
  final String text;
  final VoidCallback onTap;

  const SignupRiskAcknowledgement({
    required this.checked,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: checked ? _signupText : Colors.transparent,
              border: Border.all(color: checked ? _signupText : _signupDim),
            ),
            child: checked
                ? Icon(KeroseneIcons.check, size: 13, color: _signupInk)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: SignupTypography.bodySmall(color: _signupMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class SignupPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final double borderRadius;

  const SignupPrimaryButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.borderRadius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final background = outlined
        ? Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: disabled ? 0.02 : 0.03)
        : disabled
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42)
            : _signupText;
    final foreground = outlined ? _signupText : _signupInk;

    return AuthMotionPressScale(
      enabled: !disabled,
      child: AuthPrimaryCta(
        label: text,
        onPressed: onPressed,
        isLoading: isLoading,
        outlined: outlined,
        height: 54,
        borderRadius: BorderRadius.circular(borderRadius),
        backgroundColor: background,
        foregroundColor: foreground,
        borderColor: outlined
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16)
            : Colors.transparent,
        textStyle: SignupTypography.button(color: foreground),
      ),
    );
  }
}

class SignupPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SignupPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _signupSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _signupBorderSoft),
      ),
      child: child,
    );
  }
}

class SignupSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;

  const SignupSpinner({
    required this.size,
    required this.strokeWidth,
  });

  @override
  State<SignupSpinner> createState() => SignupSpinnerState();
}

class SignupSpinnerState extends State<SignupSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KeroseneMotion.calm,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthMotion.reduce(context)) {
      return CupertinoActivityIndicator(
        radius: widget.size / 2,
        color: _signupText,
      );
    }

    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: SignupSpinnerPainter(strokeWidth: widget.strokeWidth),
        ),
      ),
    );
  }
}

class SignupSpinnerPainter extends CustomPainter {
  final double strokeWidth;

  const SignupSpinnerPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = _signupText;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.57,
      4.7,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant SignupSpinnerPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth;
  }
}

class TotpQrBox extends StatelessWidget {
  final String data;
  final double size;

  const TotpQrBox({
    required this.data,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size >= 150 ? 12 : 8),
      decoration: BoxDecoration(
        color: _signupText,
        borderRadius: BorderRadius.circular(12),
      ),
      child: data.isEmpty
          ? Center(
              child: Icon(KeroseneIcons.qr, color: _signupInk, size: 42),
            )
          : QrImageView(data: data, version: QrVersions.auto),
    );
  }
}

class TotpDigitBoxes extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const TotpDigitBoxes({
    required this.controller,
    required this.enabled,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<TotpDigitBoxes> createState() => TotpDigitBoxesState();
}

class TotpDigitBoxesState extends State<TotpDigitBoxes> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TotpDigitBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _focus() {
    if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text.replaceAll(RegExp(r'\D'), '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.01,
            child: SizedBox(
              height: 1,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final digit = index < code.length ? code[index] : '';
              final active = _focusNode.hasFocus && index == code.length;
              return AnimatedContainer(
                duration: AuthMotion.step,
                curve: KeroseneMotion.standard,
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _signupField,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? _signupText.withValues(alpha: 0.72)
                        : _signupBorder,
                  ),
                ),
                child: Text(
                  digit,
                  style: AppTypography.bodyLarge.copyWith(
                    fontFamily: AppTypography.numericFontFamily,
                    color: _signupText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class NumberedInstruction extends StatelessWidget {
  final int number;
  final String text;

  const NumberedInstruction({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _signupMuted),
          ),
          alignment: Alignment.center,
          child: Text(
            number.toString(),
            style: SignupTypography.bodySmall(color: _signupText).copyWith(
              color: _signupText,
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: SignupTypography.bodySmall(color: _signupMuted),
          ),
        ),
      ],
    );
  }
}

class RecoveryCodesCopyButton extends StatelessWidget {
  final List<String> codes;
  final VoidCallback onCopied;

  const RecoveryCodesCopyButton({
    required this.codes,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    return AuthMotionPressScale(
      enabled: true,
      child: OutlinedButton.icon(
        onPressed: onCopied,
        icon: Icon(KeroseneIcons.copy, size: 20),
        label: Text(_signupCopyRecoveryCodesAction(context)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: _signupText,
          backgroundColor: _signupField,
          side: BorderSide(color: _signupBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: SignupTypography.button(color: _signupText).copyWith(
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

String _signupCopyRecoveryCodesAction(BuildContext context) =>
    context.tr.flowSignupCopyRecoveryCodesAction;

class SignupBullet extends StatelessWidget {
  final String text;
  final IconData icon;

  const SignupBullet({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: _signupDim, size: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: SignupTypography.bodyMedium(color: _signupMuted),
            ),
          ),
        ],
      ),
    );
  }
}
