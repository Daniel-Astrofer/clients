import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/presentation/widgets/kerosene_education_dialog.dart';

import 'send_money_screen_dependencies.dart';

class SendPaymentReviewRowData {
  final String label;
  final String value;
  final bool numeric;
  final bool technical;
  final bool emphasize;
  final bool detail;

  const SendPaymentReviewRowData({
    required this.label,
    required this.value,
    this.numeric = false,
    this.technical = false,
    this.emphasize = false,
    this.detail = false,
  });
}

class SendPaymentReceiptRowData {
  final String label;
  final String value;
  final bool numeric;
  final bool technical;

  const SendPaymentReceiptRowData({
    required this.label,
    required this.value,
    this.numeric = false,
    this.technical = false,
  });
}

class SendPaymentReceiptData {
  final String title;
  final String subtitle;
  final String amountLabel;
  final DateTime occurredAt;
  final List<SendPaymentReceiptRowData> rows;
  final String shareText;

  const SendPaymentReceiptData({
    required this.title,
    this.subtitle = '',
    required this.amountLabel,
    required this.occurredAt,
    required this.rows,
    required this.shareText,
  });
}

class InternalTransferReviewScreen<T> extends StatefulWidget {
  final String title;
  final String amountBtcLabel;
  final String fiatAmountLabel;
  final String confirmLabel;
  final String submittingLabel;
  final String? destinationLabel;
  final String? networkLabel;
  final String? fromWalletLabel;
  final List<SendPaymentReviewRowData> rows;
  final SendPaymentReviewCardData card;
  final bool requiresFirstSendAck;
  final String? firstSendAddressPreview;
  final String? firstSendAddress;
  final String? authNextStepLabel;
  final Future<T?> Function(BuildContext context) onConfirm;
  final SendPaymentReceiptData? Function(T result)? receiptBuilder;

  /// When set, close/back dismisses inline (Detalhes phase) instead of
  /// popping a GoRouter route.
  final VoidCallback? onDismiss;

  /// When set with [onDismiss], success completes the inline phase instead
  /// of `context.pop(result)`.
  final ValueChanged<T>? onCompleted;

  const InternalTransferReviewScreen({
    super.key,
    this.title = '',
    required this.amountBtcLabel,
    required this.fiatAmountLabel,
    this.confirmLabel = '',
    this.submittingLabel = '',
    this.destinationLabel,
    this.networkLabel,
    this.fromWalletLabel,
    required this.rows,
    required this.card,
    this.requiresFirstSendAck = false,
    this.firstSendAddressPreview,
    this.firstSendAddress,
    this.authNextStepLabel,
    required this.onConfirm,
    this.receiptBuilder,
    this.onDismiss,
    this.onCompleted,
  });

  @override
  State<InternalTransferReviewScreen<T>> createState() =>
      InternalTransferReviewScreenState<T>();
}

class InternalTransferReviewScreenState<T>
    extends State<InternalTransferReviewScreen<T>> {
  bool _isSubmitting = false;
  bool _firstSendAcknowledged = false;
  int _submittingPhase = 0;
  Timer? _submittingPhaseTimer;

  bool get _canAuthorize {
    if (_isSubmitting) return false;
    if (widget.requiresFirstSendAck && !_firstSendAcknowledged) return false;
    return true;
  }

  void _startSubmittingPhases() {
    _submittingPhaseTimer?.cancel();
    _submittingPhase = 0;
    _submittingPhaseTimer = Timer.periodic(const Duration(milliseconds: 900), (
      _,
    ) {
      if (!mounted || !_isSubmitting) return;
      setState(() => _submittingPhase += 1);
    });
  }

  void _stopSubmittingPhases() {
    _submittingPhaseTimer?.cancel();
    _submittingPhaseTimer = null;
    _submittingPhase = 0;
  }

  @override
  void dispose() {
    _stopSubmittingPhases();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_canAuthorize) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _submittingPhase = 0;
    });
    _startSubmittingPhases();

    // Short breath before auth gate — keep under a frame budget, not a pause.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final result = await widget.onConfirm(context);
    if (!mounted) return;

    if (result != null) {
      _stopSubmittingPhases();
      final receipt = widget.receiptBuilder?.call(result);
      if (receipt != null) {
        final receiptResult = await context.push<T>(
          '/send-money/receipt',
          extra: SendPaymentReceiptArgs<T>(
            data: receipt,
            result: result,
          ),
        );
        if (!mounted) return;
        final completed = receiptResult ?? result;
        _finishWithResult(completed);
        return;
      }

      _finishWithResult(result);
      return;
    }

    _stopSubmittingPhases();
    setState(() => _isSubmitting = false);
  }

  void _dismiss() {
    final onDismiss = widget.onDismiss;
    if (onDismiss != null) {
      onDismiss();
      return;
    }
    context.pop();
  }

  void _finishWithResult(T result) {
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted(result);
      return;
    }
    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty
        ? SendMoneyCopy.reviewTitle(context)
        : widget.title;
    final confirmLabel = widget.confirmLabel.trim().isEmpty
        ? SendMoneyCopy.authorizeAction(context)
        : widget.confirmLabel;
    final submittingLabel = widget.submittingLabel.trim().isEmpty
        ? SendMoneyCopy.authorizingPhase(context, _submittingPhase)
        : widget.submittingLabel;

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: _C.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: context.responsive.appColumnConstraints,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 32,
                                ),
                                child: Align(
                                  alignment: const Alignment(0, -0.3),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _ReviewBody(
                                        title: title,
                                        card: widget.card,
                                        onBack: _isSubmitting ? null : _dismiss,
                                      ),
                                      if (widget.requiresFirstSendAck) ...[
                                        const SizedBox(height: 20),
                                        _FirstSendAckBlock(
                                          preview:
                                              widget.firstSendAddressPreview ??
                                                  '',
                                          acknowledged: _firstSendAcknowledged,
                                          enabled: !_isSubmitting,
                                          onChanged: (value) {
                                            HapticFeedback.selectionClick();
                                            setState(() =>
                                                _firstSendAcknowledged = value);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: _AuthorizeButton(
                          label: confirmLabel,
                          submittingLabel: submittingLabel,
                          isSubmitting: _isSubmitting,
                          enabled: _canAuthorize,
                          onPressed: _confirm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: ColoredBox(
                  color: _C.background.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _C.text,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          submittingLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.inter(
                            color: _C.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SendPaymentReceiptScreen<T> extends StatefulWidget {
  final SendPaymentReceiptData data;
  final T result;

  const SendPaymentReceiptScreen({
    super.key,
    required this.data,
    required this.result,
  });

  @override
  State<SendPaymentReceiptScreen<T>> createState() =>
      _SendPaymentReceiptScreenState<T>();
}

class _SendPaymentReceiptScreenState<T>
    extends State<SendPaymentReceiptScreen<T>> {
  void _close() {
    context.pop(widget.result);
  }

  Future<void> _shareReceipt() async {
    final copiedMessage = SendMoneyCopy.receiptCopied(context);
    await Clipboard.setData(ClipboardData(text: widget.data.shareText));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    SnackbarHelper.showSuccess(copiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <SendPaymentReceiptRowData>[
      SendPaymentReceiptRowData(
        label: SendMoneyCopy.receiptDateLabel(context),
        value: _formatReceiptDate(context, widget.data.occurredAt),
        numeric: true,
      ),
      ...widget.data.rows,
    ];

    return Scaffold(
      backgroundColor: _C.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: context.responsive.appColumnConstraints,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SendFlowHeader(onClose: _close),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: _ReceiptBody(
                      title: widget.data.title,
                      subtitle: widget.data.subtitle,
                      amountLabel: widget.data.amountLabel,
                      rows: rows,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReceiptPrimaryButton(
                        label: SendMoneyCopy.receiptDoneAction(context),
                        onPressed: _close,
                      ),
                      const SizedBox(height: 10),
                      _ReceiptShareButton(
                        label: SendMoneyCopy.receiptShareAction(context),
                        onPressed: _shareReceipt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  final String title;
  final SendPaymentReviewCardData card;
  final VoidCallback? onBack;

  const _ReviewBody({
    required this.title,
    required this.card,
    this.onBack,
  });

  static const double _headerGap = 45.5; // 35 * 1.3
  static const double _sectionGap = 26; // 20 * 1.3
  static const double _rowGap = 19.5; // 15 * 1.3
  static const double _afterTopDividerGap = 20.8; // sectionGap * 0.8
  static const double _beforeTotalGap = 36.4; // headerGap * 0.8
  static const double _cardWidthFactor =
      1.0; // 0.92 * 1.10, capped at full width

  @override
  Widget build(BuildContext context) {
    final icon = card.isLightning
        ? KeroseneIcons.bolt
        : card.isOnChain
            ? KeroseneIcons.send
            : KeroseneIcons.user;

    final showAddress = card.recipientAddress.trim().isNotEmpty &&
        card.recipientAddress.trim() != card.recipientName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: SendMoneyCopy.closeTooltip(context),
              onPressed: onBack,
              icon: const Icon(KeroseneIcons.back, size: 31),
              style: IconButton.styleFrom(
                foregroundColor: _C.text,
                disabledForegroundColor: _C.muted.withValues(alpha: 0.38),
                minimumSize: const Size.square(48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.left,
                style: AppTypography.newsreader(
                  color: _C.text,
                  fontSize: 30.94,
                  fontWeight: FontWeight.w400,
                  height: 1.61,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: FractionallySizedBox(
            widthFactor: _cardWidthFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _C.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(23, 23, 23, 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _C.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(icon, color: _C.text, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.recipientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.inter(
                                  color: _C.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              if (showAddress) ...[
                                const SizedBox(height: 4),
                                Text(
                                  card.recipientAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.inter(
                                    color: _C.muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _headerGap),
                    const _ReviewDivider(),
                    const SizedBox(height: _afterTopDividerGap),
                    _AmountBlock(
                      label: SendMoneyCopy.reviewTransferAmountLabel(context),
                      amount: card.transferAmountLabel,
                      fiat: card.transferFiatLabel,
                    ),
                    if (card.transactionFeeLabel != null) ...[
                      const SizedBox(height: _rowGap),
                      _AmountBlock(
                        label: SendMoneyCopy.reviewTransactionFeeLabel(context),
                        amount: card.transactionFeeLabel!,
                        fiat: card.transactionFeeFiatLabel ?? '',
                      ),
                    ],
                    if (card.miningFeeLabel != null) ...[
                      const SizedBox(height: _rowGap),
                      _AmountBlock(
                        label: SendMoneyCopy.reviewMiningFeeLabel(context),
                        amount: card.miningFeeLabel!,
                        fiat: card.miningFeeFiatLabel ?? '',
                      ),
                    ],
                    const SizedBox(height: _sectionGap),
                    _ReviewLine(
                      label: SendMoneyCopy.networkRowLabel(context),
                      value: card.networkLabel,
                    ),
                    const SizedBox(height: _sectionGap),
                    const _ReviewDivider(),
                    const SizedBox(height: _beforeTotalGap),
                    _AmountBlock(
                      label: SendMoneyCopy.reviewTotalLabel(context),
                      amount: card.totalAmountLabel,
                      fiat: card.totalFiatLabel,
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _FraudTip(onReadMore: () => _openFraudEducation(context)),
      ],
    );
  }

  Future<void> _openFraudEducation(BuildContext context) {
    return KeroseneEducationDialog.show<void>(
      context: context,
      icon: KeroseneIcons.security,
      tone: KeroseneEducationTone.info,
      title: SendMoneyCopy.reviewFraudDialogTitle(context),
      body: SendMoneyCopy.reviewFraudDialogBody(context),
      bullets: SendMoneyCopy.reviewFraudDialogBullets(context),
      primaryLabel: MaterialLocalizations.of(context).okButtonLabel,
    );
  }
}

class _ReviewDivider extends StatelessWidget {
  const _ReviewDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              color: _C.text,
              fontSize: 12.6,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.right,
          style: AppTypography.inter(
            color: _C.text,
            fontSize: 12.6,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _AmountBlock extends StatelessWidget {
  final String label;
  final String amount;
  final String fiat;
  final bool emphasize;

  const _AmountBlock({
    required this.label,
    required this.amount,
    required this.fiat,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              color: _C.text,
              fontSize: emphasize ? 13.5 : 12.6,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              textAlign: TextAlign.right,
              style: AppTypography.amountLarge.copyWith(
                color: _C.text,
                fontSize: emphasize ? 16.2 : 14.4,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            if (fiat.trim().isNotEmpty) ...[
              const SizedBox(height: 6.5),
              Text(
                fiat.startsWith('≈') ? fiat : '≈ $fiat',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.right,
                style: AppTypography.inter(
                  color: _C.text,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _FraudTip extends StatelessWidget {
  final VoidCallback onReadMore;

  const _FraudTip({required this.onReadMore});

  @override
  Widget build(BuildContext context) {
    final lead = SendMoneyCopy.reviewFraudTipLead(context);
    final link = SendMoneyCopy.reviewFraudTipLink(context);
    final trail = SendMoneyCopy.reviewFraudTipTrail(context);

    return Text.rich(
      TextSpan(
        style: AppTypography.inter(
          color: _C.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        children: [
          TextSpan(text: lead),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onReadMore();
              },
              child: Text(
                link,
                style: AppTypography.inter(
                  color: _C.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  decoration: TextDecoration.underline,
                  decorationColor: _C.text.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          TextSpan(text: trail),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Inline first-send acknowledgement — same surface language as destination feedback.
class _FirstSendAckBlock extends StatelessWidget {
  final String preview;
  final bool acknowledged;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _FirstSendAckBlock({
    required this.preview,
    required this.acknowledged,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            SendMoneyCopy.firstSendAckTitle(context),
            style: AppTypography.inter(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SendMoneyCopy.firstSendAckBody(context),
            style: AppTypography.inter(
              color: _C.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          if (preview.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              preview,
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                color: _C.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 4),
          CheckboxListTile(
            value: acknowledged,
            onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: _C.text,
            checkColor: _C.background,
            side: const BorderSide(color: _C.border, width: 1.4),
            title: Text(
              SendMoneyCopy.firstSendAckCheckbox(context),
              style: AppTypography.inter(
                color: _C.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amountLabel;
  final List<SendPaymentReceiptRowData> rows;

  const _ReceiptBody({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkeuomorphicReceiptPainter(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ReceiptSuccessMark(),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.financial(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.financial(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              amountLabel,
              textAlign: TextAlign.center,
              style: AppTypography.financial(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.black12, height: 1, thickness: 1),
            const SizedBox(height: 24),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: AppTypography.financial(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
                        style: AppTypography.financial(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ).copyWith(
                          fontFeatures: row.numeric
                              ? const [FontFeature.tabularFigures()]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32), // space for jagged edge
          ],
        ),
      ),
    );
  }
}

class _SkeuomorphicReceiptPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF9F6F0) // Paper color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();

    const segmentWidth = 12.0;
    final segments = (size.width / segmentWidth).ceil();

    // Jagged top edge
    path.moveTo(0, 0);
    for (int i = 0; i <= segments; i++) {
      final x = (i * segmentWidth).clamp(0.0, size.width);
      final y = (i % 2 == 0) ? 0.0 : 8.0;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);

    // Jagged bottom edge
    for (int i = segments; i >= 0; i--) {
      final x = (i * segmentWidth).clamp(0.0, size.width);
      final y = (i % 2 == 0) ? size.height : size.height - 8;
      path.lineTo(x, y);
    }
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SendFlowHeader extends StatelessWidget {
  final VoidCallback? onClose;

  const _SendFlowHeader({this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: SendMoneyCopy.closeTooltip(context),
          onPressed: onClose,
          icon: const Icon(KeroseneIcons.close, size: 22),
          style: IconButton.styleFrom(
            foregroundColor: _C.muted,
            disabledForegroundColor: _C.muted.withValues(alpha: 0.38),
            minimumSize: const Size.square(44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _AuthorizeButton extends StatelessWidget {
  final String label;
  final String submittingLabel;
  final bool isSubmitting;
  final bool enabled;
  final VoidCallback onPressed;

  const _AuthorizeButton({
    required this.label,
    required this.submittingLabel,
    required this.isSubmitting,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final ready = enabled && !isSubmitting;

    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ready ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              color: ready ? _C.text : _C.surfaceHigh.withValues(alpha: 0.64),
              border: Border.all(
                color: ready ? _C.text : _C.border,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Green progress wipe on authorize (original motion).
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: isSubmitting ? 1 : 0),
                    duration: const Duration(milliseconds: 920),
                    curve: Curves.easeInOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: child,
                      );
                    },
                    child: const ColoredBox(color: _C.success),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Row(
                        key: ValueKey<String>(
                          isSubmitting ? 's:$submittingLabel' : 'idle',
                        ),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSubmitting ? submittingLabel : label,
                            style: AppTypography.inter(
                              color: ready || isSubmitting
                                  ? _C.background
                                  : _C.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSubmitting
                                ? KeroseneIcons.security
                                : KeroseneIcons.lock,
                            color: ready || isSubmitting
                                ? _C.background
                                : _C.muted,
                            size: 18,
                          ),
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
}

class _ReceiptSuccessMark extends StatelessWidget {
  const _ReceiptSuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _C.success.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          KeroseneIcons.check,
          color: _C.success,
          size: 34,
        ),
      ),
    );
  }
}

class _ReceiptPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ReceiptPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _C.text,
          foregroundColor: _C.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ReceiptShareButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ReceiptShareButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.text,
          side: const BorderSide(color: _C.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        icon: const Icon(KeroseneIcons.share, size: 17),
        label: Text(label),
      ),
    );
  }
}

String receiptAmountLabelFromStatus({
  required TxStatus status,
  required double fallbackAmountBtc,
}) {
  final amount =
      status.amountReceived > 0 ? status.amountReceived : fallbackAmountBtc;
  return formatBtcValue(amount);
}

String compactSendReceiptValue(String value, {int head = 12, int tail = 8}) {
  final trimmed = value.trim();
  if (trimmed.length <= head + tail + 3) return trimmed;
  return '${trimmed.substring(0, head)}...${trimmed.substring(trimmed.length - tail)}';
}

String _formatReceiptDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  final months = switch (locale) {
    'en' => const [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ],
    'es' => const [
        'ENE',
        'FEB',
        'MAR',
        'ABR',
        'MAY',
        'JUN',
        'JUL',
        'AGO',
        'SEP',
        'OCT',
        'NOV',
        'DIC',
      ],
    _ => const [
        'JAN',
        'FEV',
        'MAR',
        'ABR',
        'MAI',
        'JUN',
        'JUL',
        'AGO',
        'SET',
        'OUT',
        'NOV',
        'DEZ',
      ],
  };
  final day = value.day.toString().padLeft(2, '0');
  final month = months[value.month - 1];
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day $month ${value.year} · $hour:$minute';
}

/// Local palette aliases — all map to [KeroseneBrandTokens] for platform coherence.
class _C {
  const _C._();

  static const background = KeroseneBrandTokens.background;
  static const surface = KeroseneBrandTokens.surface;
  static const surfaceHigh = KeroseneBrandTokens.surfaceHigh;
  static const border = KeroseneBrandTokens.border;
  static const text = KeroseneBrandTokens.textPrimary;
  static const secondary = KeroseneBrandTokens.textSecondary;
  static const muted = KeroseneBrandTokens.textMuted;
  static const success = KeroseneBrandTokens.success;

  /// Dark authorize chrome (pre-wipe), matching original send review button.
  static const button = KeroseneBrandTokens.surfaceElevated;
  static const buttonText = KeroseneBrandTokens.textSecondary;
}
