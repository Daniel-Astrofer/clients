import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_motion.dart';

Color _authBlack(BuildContext context) =>
    KeroseneBrandTheme.of(context).background;
Color _authWhite(BuildContext context) =>
    KeroseneBrandTheme.of(context).textPrimary;
Color _authMuted(BuildContext context) =>
    KeroseneBrandTheme.of(context).textMuted;
Color _authSurface(BuildContext context) =>
    KeroseneBrandTheme.of(context).surface;
Color _authSurfaceRaised(BuildContext context) =>
    KeroseneBrandTheme.of(context).surfaceElevated;
Color _authBorder(BuildContext context) =>
    KeroseneBrandTheme.of(context).border;
Color _authErrorText(BuildContext context) => _authWhite(context);
Color _authSuccess(BuildContext context) => _authWhite(context);

class PasskeyIssueInfo {
  final IconData icon;
  final String title;
  final String message;
  final bool allowRetry;
  final bool allowTotpFallback;

  const PasskeyIssueInfo({
    required this.icon,
    required this.title,
    required this.message,
    this.allowRetry = true,
    this.allowTotpFallback = true,
  });
}

class TopBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const TopBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AuthMotionPressScale(
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onPressed,
          icon: const KeroseneIcon(KeroseneIcons.back, size: 24),
          color: _authWhite(context).withValues(alpha: 0.84),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class PasskeyAuthView extends StatelessWidget {
  final Animation<double> animation;
  final String title;
  final String subtitle;
  final bool isShort;
  final bool isSuccess;

  const PasskeyAuthView({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.isShort,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final sensorSize = responsive.isTinyPhone
        ? 132.0
        : isShort
            ? 112.0
            : 152.0;
    final iconSize = sensorSize * 0.42;
    final titleSize = responsive.isTinyPhone || isShort ? 28.0 : 30.0;

    return ConstrainedBox(
      constraints: responsive.formConstraints,
      child: AuthMotionStagger(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SensorVisualizer(
            animation: animation,
            size: sensorSize,
            iconSize: iconSize,
            isSuccess: isSuccess,
          ),
          SizedBox(height: isShort ? AppSpacing.lg : 46),
          Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: _authWhite(context),
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                  letterSpacing: 0,
                ),
              )),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: _authMuted(context),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class SensorVisualizer extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final double iconSize;
  final bool isSuccess;

  const SensorVisualizer({
    required this.animation,
    required this.size,
    required this.iconSize,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final sensor = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _authSurface(context),
        border: Border.all(color: _authWhite(context).withValues(alpha: 0.08)),
      ),
      child: KeroseneIcon(
        isSuccess ? KeroseneIcons.success : KeroseneIcons.biometric,
        size: iconSize,
        color: isSuccess ? _authSuccess(context) : _authWhite(context),
      ),
    );
    if (AuthMotion.reduce(context) || isSuccess) return sensor;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animation,
        child: sensor,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.98 + math.sin(animation.value * math.pi) * 0.02,
            child: child,
          );
        },
      ),
    );
  }
}

class PasskeyIssueView extends StatelessWidget {
  final PasskeyIssueInfo? issue;
  final bool isShort;
  final bool canRetry;
  final bool canUseTotp;
  final VoidCallback? onRetry;
  final VoidCallback? onUseTotp;
  final VoidCallback? onBackToPassword;
  final VoidCallback? onRecoverAccount;
  final String Function({
    required String pt,
    required String en,
    required String es,
  }) copy;

  const PasskeyIssueView({
    required this.issue,
    required this.isShort,
    required this.canRetry,
    required this.canUseTotp,
    required this.onRetry,
    required this.onUseTotp,
    required this.onBackToPassword,
    this.onRecoverAccount,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final titleSize = responsive.isTinyPhone || isShort ? 28.0 : 30.0;
    final message = issue?.message ??
        copy(
          pt: 'Biometria não reconhecida. Tente novamente ou use outro método.',
          en: 'Biometrics were not recognized. Try again or use another method.',
          es: 'Biometría no reconocida. Intenta de nuevo o usa otro método.',
        );

    return ConstrainedBox(
      constraints: responsive.formConstraints,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ErrorGlyph(size: isShort ? 92 : 120, icon: issue?.icon),
          SizedBox(height: isShort ? AppSpacing.lg : AppSpacing.xl),
          Text(
            issue?.title ??
                copy(
                  pt: 'Falha na Autenticação',
                  en: 'Authentication Failed',
                  es: 'Falló la Autenticación',
                ),
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              color: _authWhite(context).withValues(alpha: 0.96),
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: _authErrorText(context),
              fontSize: 14,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: isShort ? AppSpacing.xl : 58),
          if (canRetry)
            ActionButton(
              text: copy(
                pt: context.tr.settingsDevicesRetry,
                en: 'Try again',
                es: 'Intentar de nuevo',
              ).toUpperCase(),
              onPressed: onRetry,
            ),
          if (canRetry) const SizedBox(height: AppSpacing.md),
          if (canUseTotp)
            ActionButton(
              text: copy(
                pt: 'Usar TOTP',
                en: 'Use TOTP',
                es: 'Usar TOTP',
              ).toUpperCase(),
              onPressed: onUseTotp,
              secondary: true,
            )
          else
            ActionButton(
              text: copy(
                pt: 'Voltar para senha',
                en: 'Back to password',
                es: 'Volver a contraseña',
              ).toUpperCase(),
              onPressed: onBackToPassword,
              secondary: true,
            ),
          if (onRecoverAccount != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRecoverAccount,
              child: Text(copy(
                pt: 'Recuperar conta',
                en: 'Recover account',
                es: 'Recuperar cuenta',
              )),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorGlyph extends StatelessWidget {
  final double size;
  final IconData? icon;

  const ErrorGlyph({
    required this.size,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _authSurface(context),
              border: Border.all(
                  color: _authErrorText(context).withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: _authErrorText(context).withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: KeroseneIcon(
              icon ?? KeroseneIcons.biometric,
              color: _authErrorText(context),
              size: size * 0.46,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: _authErrorText(context),
                shape: BoxShape.circle,
                border: Border.all(color: _authBlack(context), width: 2),
              ),
              child: KeroseneIcon(
                KeroseneIcons.warning,
                size: size * 0.16,
                color: _authBlack(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TotpFallbackView extends StatelessWidget {
  final String code;
  final bool hasError;
  final String? errorMessage;
  final int errorPulseKey;
  final bool isLoading;
  final bool isShort;
  final KeroseneResponsiveMetrics responsive;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final String Function({
    required String pt,
    required String en,
    required String es,
  }) copy;

  const TotpFallbackView({
    required this.code,
    required this.hasError,
    required this.errorMessage,
    required this.errorPulseKey,
    required this.isLoading,
    required this.isShort,
    required this.responsive,
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = responsive.isTinyPhone
        ? 34.0
        : isShort
            ? 31.0
            : 40.0;
    final keypadGap = isShort ? AppSpacing.xs : AppSpacing.md;

    return ConstrainedBox(
      constraints: responsive.formConstraints,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            copy(
              pt: 'Código de Segurança',
              en: 'Security Code',
              es: 'Código de Seguridad',
            ),
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              color: _authWhite(context),
              fontSize: titleSize,
              fontWeight: FontWeight.w500,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy(
              pt: 'Insira o código de 6 dígitos do seu app autenticador',
              en: 'Enter the 6-digit code from your authenticator app',
              es: 'Ingresa el código de 6 dígitos de tu app autenticadora',
            ),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: _authMuted(context),
              fontSize: responsive.isTinyPhone ? 14 : 16,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: isShort ? AppSpacing.lg : 48),
          AuthMotionShake(
            triggerKey: errorPulseKey,
            enabled: hasError,
            child: PinDots(codeLength: code.length, hasError: hasError),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: _authErrorText(context),
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
          ],
          SizedBox(height: isShort ? AppSpacing.lg : 46),
          TotpKeypad(
            isShort: isShort,
            gap: keypadGap,
            onDigit: isLoading ? null : onDigit,
            onDelete: isLoading ? null : onDelete,
          ),
          SizedBox(height: isShort ? AppSpacing.lg : AppSpacing.xl),
          ActionButton(
            text: copy(
              pt: 'Confirmar',
              en: 'Confirm',
              es: 'Confirmar',
            ),
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  final int codeLength;
  final bool hasError;

  const PinDots({
    required this.codeLength,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < codeLength;
        return AnimatedContainer(
          duration: KeroseneMotion.short,
          curve: KeroseneMotion.standard,
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? _authWhite(context)
                : hasError
                    ? _authErrorText(context).withValues(alpha: 0.12)
                    : _authSurface(context),
            border: Border.all(
              color: filled
                  ? _authWhite(context)
                  : hasError
                      ? _authErrorText(context)
                      : _authBorder(context),
            ),
          ),
        );
      }),
    );
  }
}

class TotpKeypad extends StatelessWidget {
  final bool isShort;
  final double gap;
  final ValueChanged<String>? onDigit;
  final VoidCallback? onDelete;

  const TotpKeypad({
    required this.isShort,
    required this.gap,
    required this.onDigit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KeypadRow(values: const ['1', '2', '3'], gap: gap, onDigit: onDigit),
        SizedBox(height: gap),
        KeypadRow(values: const ['4', '5', '6'], gap: gap, onDigit: onDigit),
        SizedBox(height: gap),
        KeypadRow(values: const ['7', '8', '9'], gap: gap, onDigit: onDigit),
        SizedBox(height: gap),
        Row(
          children: [
            const Expanded(child: SizedBox(height: 58)),
            SizedBox(width: gap),
            Expanded(
              child: KeypadButton(
                value: '0',
                isShort: isShort,
                onPressed: onDigit == null ? null : () => onDigit?.call('0'),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: KeypadButton(
                icon: KeroseneIcons.backspace,
                isShort: isShort,
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class KeypadRow extends StatelessWidget {
  final List<String> values;
  final double gap;
  final ValueChanged<String>? onDigit;

  const KeypadRow({
    required this.values,
    required this.gap,
    required this.onDigit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Expanded(
            child: KeypadButton(
              value: values[index],
              onPressed:
                  onDigit == null ? null : () => onDigit?.call(values[index]),
            ),
          ),
          if (index != values.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class KeypadButton extends StatelessWidget {
  final String? value;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isShort;

  const KeypadButton({
    this.value,
    this.icon,
    this.onPressed,
    this.isShort = false,
  });

  @override
  Widget build(BuildContext context) {
    return AuthMotionPressScale(
      enabled: onPressed != null,
      child: SizedBox(
        height: isShort ? 46 : 64,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Center(
              child: icon != null
                  ? KeroseneIcon(icon, color: _authMuted(context), size: 22)
                  : Text(
                      value ?? '',
                      style: AppTypography.inter(
                        color: _authWhite(context),
                        fontSize: isShort ? 25 : 29,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool isLoading;

  const ActionButton({
    required this.text,
    required this.onPressed,
    this.secondary = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final background =
        secondary ? _authSurfaceRaised(context) : _authWhite(context);
    final foreground = secondary ? _authWhite(context) : _authBlack(context);

    return AuthMotionPressScale(
      enabled: !disabled,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: disabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed?.call();
                  },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    disabled ? background.withValues(alpha: 0.42) : background,
                border: Border.all(
                  color: secondary
                      ? _authSurfaceRaised(context)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: isLoading
                    ? CupertinoActivityIndicator(
                        radius: 9,
                        color: foreground,
                      )
                    : Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.buttonText.copyWith(
                          color: disabled
                              ? foreground.withValues(alpha: 0.7)
                              : foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
