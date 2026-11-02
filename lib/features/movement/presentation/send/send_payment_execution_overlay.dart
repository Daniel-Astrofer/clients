import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/constants/localized_copy.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// One execution per presentation. Results remain visible until acknowledged.
/// Dismissing a failure returns to review without replaying the operation.
class SendPaymentExecutionOverlay<T> extends StatefulWidget {
  final Future<T?> Function() onExecute;
  final String loadingMessage;
  final String successMessage;
  final String errorMessage;
  // Kept for caller compatibility. Completion is now acknowledged by the user.
  final Duration successDelay;

  const SendPaymentExecutionOverlay({
    super.key,
    required this.onExecute,
    this.loadingMessage = '',
    this.successMessage = '',
    this.errorMessage = '',
    this.successDelay = Duration.zero,
  });

  static Future<R?> show<R>(
    BuildContext context, {
    required Future<R?> Function() onExecute,
    String loadingMessage = '',
    String successMessage = '',
    String errorMessage = '',
    Duration successDelay = Duration.zero,
  }) {
    return showGeneralDialog<R>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      transitionDuration:
          KeroseneMotion.duration(context, KeroseneMotion.short),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => SendPaymentExecutionOverlay<R>(
        onExecute: onExecute,
        loadingMessage: loadingMessage,
        successMessage: successMessage,
        errorMessage: errorMessage,
        successDelay: successDelay,
      ),
    );
  }

  @override
  State<SendPaymentExecutionOverlay<T>> createState() => _ExecutionState<T>();
}

class _ExecutionState<T> extends State<SendPaymentExecutionOverlay<T>> {
  bool? _result;
  bool _uncertain = false;
  String? _errorDetails;

  @override
  void initState() {
    super.initState();
    // Payment notifiers publish loading state. That mutation must occur after
    // the dialog is mounted, never while Riverpod is building the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.of(context)?.isActive ?? true)) {
        _execute();
      }
    });
  }

  Future<void> _execute() async {
    try {
      final result = await widget.onExecute();
      if (!mounted) return;
      if (result != null && result != false) {
        _finish(result);
        return;
      }
      setState(() {
        _result = false;
        _uncertain = result == null;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is PaymentAuthorizationCancelledException) {
        _finish();
        return;
      }
      setState(() {
        _result = false;
        _uncertain = error is PaymentRecoveryException
            ? error.outcomeUncertain
            : !(error is AppException &&
                const [401, 403, 428].contains(error.statusCode));
        // A structured refusal must remain visible in the execution dialog.
        // Network failures and unknown results still require reconciliation.
        if (error is AppException) {
          _errorDetails =
              ErrorTranslator.translate(context.tr, error.toString());
        }
      });
    }
  }

  void _finish([T? result]) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isActive) return;
    final navigator = Navigator.of(context);
    if (route?.isCurrent ?? true) {
      navigator.pop<T>(result);
    } else if (route != null) {
      navigator.removeRoute(route, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _result == null;
    final title = busy
        ? (widget.loadingMessage.isNotEmpty
            ? widget.loadingMessage
            : const LocalizedCopy(
                    en: 'Processing payment',
                    pt: 'Processando envio',
                    es: 'Procesando envío')
                .resolve(context))
        : _result!
            ? (widget.successMessage.isNotEmpty
                ? widget.successMessage
                : context.tr.txListConfirmed)
            : widget.errorMessage.isNotEmpty
                ? widget.errorMessage
                : _uncertain
                    ? const LocalizedCopy(
                            en: 'Checking the result',
                            pt: 'Resultado em verificação',
                            es: 'Resultado en verificación')
                        .resolve(context)
                    : const LocalizedCopy(
                            en: 'This step could not be completed',
                            pt: 'Não foi possível concluir esta etapa',
                            es: 'No se pudo completar este paso')
                        .resolve(context);
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
                                ? KeroseneIcon(KeroseneIcons.pending,
                                    color: scheme.onSurface)
                                : const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                      )
                    : KeroseneIcon(
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
                if (_uncertain && _errorDetails != null) ...[
                  Text(_errorDetails!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium
                          .copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                ],
                Text(
                  (_uncertain ? null : _errorDetails) ??
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
                AppButton(
                  label: (_result!
                          ? const LocalizedCopy(
                              en: 'Done', pt: 'Concluir', es: 'Finalizar')
                          : const LocalizedCopy(
                              en: 'Back to review',
                              pt: 'Voltar à revisão',
                              es: 'Volver a la revisión'))
                      .resolve(context),
                  onPressed: _finish,
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
