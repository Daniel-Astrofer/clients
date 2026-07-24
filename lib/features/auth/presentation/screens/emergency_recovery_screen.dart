import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/generic/kerosene_logo.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/components/inputs/app_text_field.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';
import 'package:kerosene/features/auth/application/providers/emergency_recovery_service_provider.dart';

enum _RecoveryStep { start, verify, complete }

class EmergencyRecoveryScreen extends ConsumerStatefulWidget {
  const EmergencyRecoveryScreen({super.key});

  @override
  ConsumerState<EmergencyRecoveryScreen> createState() =>
      _EmergencyRecoveryScreenState();
}

class _EmergencyRecoveryScreenState
    extends ConsumerState<EmergencyRecoveryScreen> {
  final _usernameController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _confirmPassphraseController = TextEditingController();
  final _totpController = TextEditingController();
  final List<TextEditingController> _codeControllers =
      List.generate(3, (_) => TextEditingController());

  _RecoveryStep _step = _RecoveryStep.start;
  EmergencyRecoveryStartResult? _started;
  EmergencyRecoveryFinishResult? _finished;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    _totpController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Theme.of(context).brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light)
            .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: context.responsive.formConstraints,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl2,
                      AppSpacing.base,
                      AppSpacing.xl2,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RecoveryTopBar(
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          const Center(
                            child: KeroseneLogo(size: 46, showText: false),
                          ),
                          const SizedBox(height: AppSpacing.xl2),
                          _RecoveryTitle(
                            eyebrow: context.tr.emergencyRecoveryEyebrow,
                            title: _titleForStep(),
                            body: _bodyForStep(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.xl2),
                            _RecoveryNotice(
                              icon: KeroseneIcons.error,
                              title: context.tr.emergencyRecoveryUnableContinue,
                              message: _error!,
                              tone: _RecoveryNoticeTone.error,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl2),
                          switch (_step) {
                            _RecoveryStep.start => _buildStartStep(),
                            _RecoveryStep.verify => _buildVerifyStep(),
                            _RecoveryStep.complete => _buildCompleteStep(),
                          },
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    return switch (_step) {
      _RecoveryStep.start => context.tr.emergencyRecoveryTitleStart,
      _RecoveryStep.verify => context.tr.emergencyRecoveryTitleVerify,
      _RecoveryStep.complete => context.tr.emergencyRecoveryTitleComplete,
    };
  }

  String _bodyForStep() {
    return switch (_step) {
      _RecoveryStep.start => context.tr.emergencyRecoveryBodyStart,
      _RecoveryStep.verify => context.tr.emergencyRecoveryBodyVerify,
      _RecoveryStep.complete => context.tr.emergencyRecoveryBodyComplete,
    };
  }

  Widget _buildStartStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryTextField(
          controller: _usernameController,
          label: context.tr.username,
          icon: KeroseneIcons.user,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.base),
        _RecoveryTextField(
          controller: _passphraseController,
          label: context.tr.emergencyRecoveryNewPassword,
          icon: KeroseneIcons.lock,
          enabled: !_busy,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.base),
        _RecoveryTextField(
          controller: _confirmPassphraseController,
          label: context.tr.emergencyRecoveryConfirmPassword,
          icon: KeroseneIcons.passkey,
          enabled: !_busy,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.xl2),
        Text(
          context.tr.emergencyRecoveryCodesLabel,
          style: AppTypography.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _codeControllers.length; i++) ...[
          _RecoveryTextField(
            controller: _codeControllers[i],
            label: context.tr.emergencyRecoveryCodeN(i + 1),
            icon: KeroseneIcons.binary,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            textInputAction: i == _codeControllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy || _codeControllers.length >= 10
                ? null
                : _addRecoveryCodeField,
            icon: const Icon(KeroseneIcons.plus, size: 16),
            label: Text(
              context.tr.emergencyRecoveryAddCode,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryStartAction,
          loading: _busy,
          onPressed: _busy ? null : _startRecovery,
        ),
      ],
    );
  }

  Widget _buildVerifyStep() {
    final started = _started;
    if (started == null) {
      return const SizedBox.shrink();
    }

    final minutes = (started.expiresInSeconds / 60).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryNotice(
          icon: KeroseneIcons.timer,
          title: context.tr.emergencyRecoveryTempSession,
          message: context.tr.emergencyRecoveryFinishWithin(minutes),
          tone: _RecoveryNoticeTone.info,
        ),
        const SizedBox(height: AppSpacing.xl2),
        _TotpQrPanel(
          data: started.otpUri,
          onCopy: () => _copyToClipboard(started.otpUri),
        ),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryTextField(
          controller: _totpController,
          label: context.tr.totpCodeLabel,
          icon: KeroseneIcons.security,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_busy) {
              _finishRecovery();
            }
          },
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryConfirmPasskey,
          loading: _busy,
          onPressed: _busy ? null : _finishRecovery,
        ),
        const SizedBox(height: AppSpacing.base),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _step = _RecoveryStep.start;
                    _started = null;
                    _error = null;
                  });
                },
          child: Text(
            context.tr.emergencyRecoveryGoBackReview,
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    final finished = _finished;
    final codes = finished?.newBackupCodes ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryNotice(
          icon: KeroseneIcons.success,
          title: context.tr.emergencyRecoveryCredentialsRotated,
          message: context.tr
              .emergencyRecoveryAccountRotatedBody(finished?.username ?? ''),
          tone: _RecoveryNoticeTone.success,
        ),
        const SizedBox(height: AppSpacing.xl2),
        _BackupCodesGrid(codes: codes),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryCopyNewCodes,
          icon: KeroseneIcons.copy,
          loading: false,
          onPressed: codes.isEmpty
              ? null
              : () => _copyToClipboard(
                    codes.join('\n'),
                  ),
        ),
        const SizedBox(height: AppSpacing.base),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false),
          icon: const Icon(KeroseneIcons.login, size: 18),
          label: Text(
            context.tr.emergencyRecoverySignInAgain,
          ),
        ),
      ],
    );
  }

  void _addRecoveryCodeField() {
    setState(() => _codeControllers.add(TextEditingController()));
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  Future<void> _startRecovery() async {
    final username = _usernameController.text.trim().toLowerCase();
    final passphrase = _passphraseController.text;
    final confirmPassphrase = _confirmPassphraseController.text;
    final codes = _codeControllers
        .map((controller) => controller.text.trim())
        .where((code) => code.isNotEmpty)
        .toList(growable: false);

    final validationError = _validateStart(
      username: username,
      passphrase: passphrase,
      confirmPassphrase: confirmPassphrase,
      codes: codes,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final started = await ref.read(emergencyRecoveryServiceProvider).start(
            EmergencyRecoveryStartDraft(
              username: username,
              newPassphrase: passphrase,
              recoveryCodes: codes,
            ),
          );
      if (!mounted) return;
      setState(() {
        _started = started;
        _step = _RecoveryStep.verify;
      });
    } catch (error) {
      _setTranslatedError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _finishRecovery() async {
    final started = _started;
    if (started == null) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = context.tr.emergencyRecoveryTotpInstruction;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final finished = await ref.read(emergencyRecoveryServiceProvider).finish(
            username: _usernameController.text.trim().toLowerCase(),
            started: started,
            totpCode: totp,
          );
      if (!mounted) return;
      setState(() {
        _finished = finished;
        _step = _RecoveryStep.complete;
      });
    } catch (error) {
      _setTranslatedError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String? _validateStart({
    required String username,
    required String passphrase,
    required String confirmPassphrase,
    required List<String> codes,
  }) {
    if (username.length < 3) {
      return context.tr.authUsernameRequiredMessage;
    }
    if (passphrase.length < 12) {
      return context.tr.emergencyRecoveryPasswordMin;
    }
    if (passphrase != confirmPassphrase) {
      return context.tr.emergencyRecoveryPasswordMismatch;
    }
    if (codes.length < 3) {
      return context.tr.emergencyRecoveryNeedThreeCodes;
    }
    if (codes.toSet().length != codes.length) {
      return context.tr.emergencyRecoveryCodesDistinct;
    }
    if (codes.any((code) => !RegExp(r'^\d{8}$').hasMatch(code))) {
      return context.tr.emergencyRecoveryCodeEightDigits;
    }
    return null;
  }

  void _setTranslatedError(Object error) {
    if (!mounted) return;
    final message = error is AppException
        ? ErrorTranslator.translate(context.tr, error.message)
        : ErrorTranslator.translate(context.tr, error.toString());
    setState(() => _error = message);
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr.emergencyRecoveryCopied,
        ),
      ),
    );
  }
}

class _RecoveryTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _RecoveryTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(KeroseneIcons.back, size: 22),
          color: Theme.of(context).colorScheme.onSurface,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const Spacer(),
      ],
    );
  }
}

class _RecoveryTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;

  const _RecoveryTitle({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.h1.copyWith(
            fontSize: 31,
            fontWeight: FontWeight.w500,
            height: 1.08,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
        ),
      ],
    );
  }
}

class _RecoveryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _RecoveryTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      label: label,
      prefixIcon: Icon(icon, size: 18),
    );
  }
}

enum _RecoveryNoticeTone { info, success, error }

class _RecoveryNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final _RecoveryNoticeTone tone;

  const _RecoveryNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _RecoveryNoticeTone.info => AppColors.secondary,
      _RecoveryNoticeTone.success => AppColors.success,
      _RecoveryNoticeTone.error => AppColors.error,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotpQrPanel extends StatelessWidget {
  final String data;
  final VoidCallback onCopy;

  const _TotpQrPanel({
    required this.data,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 212,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            SelectableText(
              data,
              maxLines: 2,
              style: AppTypography.technicalMono(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(KeroseneIcons.copy, size: 16),
              label: Text(MaterialLocalizations.of(context).copyButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCodesGrid extends StatelessWidget {
  final List<String> codes;

  const _BackupCodesGrid({required this.codes});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final code in codes)
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              border: Border.all(color: AppColors.white10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: AppTypography.technicalMono(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecoveryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _RecoveryActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      expand: true,
      icon: Icon(icon ?? KeroseneIcons.next, size: 18),
    );
  }
}
