import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/constants/localized_copy.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// One execution per presentation. Results remain visible until acknowledged.
/// Dismissing a failure returns to review without replaying the operation.
class SendPaymentExecutionOverlay extends StatefulWidget {
  final Future<bool> Function() onExecute;
  final String loadingMessage;
  final String successMessage;
  final String errorMessage;
  // Kept for caller compatibility. Completion is now acknowledged by the user.
  final Duration successDelay;

  const SendPaymentExecutionOverlay({
    super.key,
    required this.onExecute,
    this.loadingMessage = 'Validando...',
    this.successMessage = 'Confirmada',
    this.errorMessage = 'Não foi possível processar',
    this.successDelay = Duration.zero,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Future<bool> Function() onExecute,
    String loadingMessage = 'Validando...',
    String successMessage = 'Confirmada',
    String errorMessage = 'Não foi possível processar',
    Duration successDelay = Duration.zero,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      transitionDuration:
          KeroseneMotion.duration(context, KeroseneMotion.short),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => SendPaymentExecutionOverlay(
        onExecute: onExecute,
        loadingMessage: loadingMessage,
        successMessage: successMessage,
        errorMessage: errorMessage,
        successDelay: successDelay,
      ),
    );
  }

  @override
  State<SendPaymentExecutionOverlay> createState() => _ExecutionState();
}

class _ExecutionState extends State<SendPaymentExecutionOverlay> {
  bool? _result;
  bool _uncertain = false;

  @override
  void initState() {
    super.initState();
    _execute();
  }

  Future<void> _execute() async {
    try {
      final result = await widget.onExecute();
      if (!mounted) return;
      setState(() => _result = result);
      if (result) HapticFeedback.lightImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = false;
        _uncertain = true;
      });
    }
  }

  void _retry() {
    if (_result == null) return;
    setState(() {
      _result = null;
      _uncertain = false;
    });
    _execute();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _result == null;
    final title = busy
        ? widget.loadingMessage
        : _result!
            ? widget.successMessage
            : widget.errorMessage;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: KeroseneMotion.duration(
                    context, KeroseneMotion.statusChange),
                child: busy
                    ? SizedBox(
                        key: const ValueKey('payment-processing'),
                        height: 40,
                        child: Center(
                            child: KeroseneMotion.reduceMotion(context)
                                ? Icon(KeroseneIcons.pending,
                                    color: scheme.onSurface)
                                : const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                      )
                    : Icon(
                        _result!
                            ? KeroseneIcons.success
                            : KeroseneIcons.warning,
                        key: ValueKey(_result),
                        size: 36,
                        color: _result! ? scheme.onSurface : scheme.error),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: AppTypography.h3Small
                        .copyWith(color: scheme.onSurface)),
              ),
              if (_result == false) ...[
                const SizedBox(height: 12),
                Text(
                  (_uncertain
                          ? const LocalizedCopy(
                              en:
                                  'The result could not be confirmed. Check your activity before trying again.',
                              pt:
                                  'Não foi possível confirmar o resultado. Confira sua atividade antes de tentar novamente.',
                              es:
                                  'No se pudo confirmar el resultado. Revisa tu actividad antes de intentarlo de nuevo.')
                          : const LocalizedCopy(
                              en: 'Your payment details are saved in the review.',
                              pt: 'Os dados do pagamento foram mantidos na revisão.',
                              es: 'Los datos del pago se mantienen en la revisión.'))
                      .resolve(context),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (!busy) ...[
                const SizedBox(height: 24),
                if (_result == false) ...[
                  AppButton(
                    label: const LocalizedCopy(
                      en: 'Try again',
                      pt: 'Tentar novamente',
                      es: 'Intentar de nuevo',
                    ).resolve(context),
                    variant: AppButtonVariant.secondary,
                    onPressed: _retry,
                    expand: true,
                  ),
                  const SizedBox(height: 10),
                ],
                AppButton(
                  label: (_result!
                          ? const LocalizedCopy(
                              en: 'Done', pt: 'Concluir', es: 'Finalizar')
                          : const LocalizedCopy(
                              en: 'Back to review',
                              pt: 'Voltar à revisão',
                              es: 'Volver a la revisión'))
                      .resolve(context),
                  onPressed: () => Navigator.of(context).pop(_result),
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
