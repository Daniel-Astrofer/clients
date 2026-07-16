import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';
import 'package:kerosene/features/movement/widgets/movement_confirmation_surface.dart';

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
  final bool requiresFirstSendAck;
  final String? firstSendAddressPreview;
  final String? firstSendAddress;
  final String? authNextStepLabel;
  final Future<T?> Function(BuildContext context) onConfirm;
  final SendPaymentReceiptData? Function(T result)? receiptBuilder;

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
    this.requiresFirstSendAck = false,
    this.firstSendAddressPreview,
    this.firstSendAddress,
    this.authNextStepLabel,
    required this.onConfirm,
    this.receiptBuilder,
  });

  @override
  State<InternalTransferReviewScreen<T>> createState() =>
      InternalTransferReviewScreenState<T>();
}

class InternalTransferReviewScreenState<T>
    extends State<InternalTransferReviewScreen<T>> {
  bool _isSubmitting = false;
  bool _firstSendAcknowledged = false;

  bool get _canAuthorize {
    if (_isSubmitting) return false;
    if (widget.requiresFirstSendAck && !_firstSendAcknowledged) return false;
    return true;
  }

  Future<void> _confirm() async {
    if (!_canAuthorize) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    // Brief breath before auth gate — soft, not theatrical.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    final result = await widget.onConfirm(context);
    if (!mounted) return;

    if (result != null) {
      final receipt = widget.receiptBuilder?.call(result);
      if (receipt != null) {
        final receiptResult = await Navigator.of(context).push<T>(
          MaterialPageRoute<T>(
            builder: (_) => SendPaymentReceiptScreen<T>(
              data: receipt,
              result: result,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(receiptResult ?? result);
        return;
      }

      Navigator.of(context).pop(result);
      return;
    }

    setState(() => _isSubmitting = false);
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
        ? SendMoneyCopy.authorizingAction(context)
        : widget.submittingLabel;
    final authNext = widget.authNextStepLabel?.trim() ?? '';

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: _C.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SendFlowHeader(
                    onClose: _isSubmitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ReviewBody(
                            title: title,
                            amountBtcLabel: widget.amountBtcLabel,
                            fiatAmountLabel: widget.fiatAmountLabel,
                            destinationLabel: widget.destinationLabel,
                            networkLabel: widget.networkLabel,
                            fromWalletLabel: widget.fromWalletLabel,
                            rows: widget.rows,
                          ),
                          if (widget.requiresFirstSendAck) ...[
                            const SizedBox(height: 20),
                            _FirstSendAckBlock(
                              preview: widget.firstSendAddressPreview ?? '',
                              acknowledged: _firstSendAcknowledged,
                              enabled: !_isSubmitting,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() => _firstSendAcknowledged = value);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (authNext.isNotEmpty) ...[
                          Text(
                            authNext,
                            textAlign: TextAlign.center,
                            style: AppTypography.inter(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AuthorizeButton(
                          label: confirmLabel,
                          submittingLabel: submittingLabel,
                          isSubmitting: _isSubmitting,
                          enabled: _canAuthorize,
                          onPressed: _confirm,
                        ),
                      ],
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
    Navigator.of(context).pop<T>(widget.result);
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
            constraints: const BoxConstraints(maxWidth: 480),
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

class _ReviewBody extends StatefulWidget {
  final String title;
  final String amountBtcLabel;
  final String fiatAmountLabel;
  final String? destinationLabel;
  final String? networkLabel;
  final String? fromWalletLabel;
  final List<SendPaymentReviewRowData> rows;

  const _ReviewBody({
    required this.title,
    required this.amountBtcLabel,
    required this.fiatAmountLabel,
    this.destinationLabel,
    this.networkLabel,
    this.fromWalletLabel,
    required this.rows,
  });

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  bool _detailsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final party = widget.destinationLabel?.trim() ?? '';
    final network = widget.networkLabel?.trim() ?? '';
    final from = widget.fromWalletLabel?.trim() ?? '';
    // Summary (destination / ETA) → optional details → total last.
    final summary = widget.rows
        .where((r) => !r.detail && !r.emphasize)
        .toList(growable: false);
    final details =
        widget.rows.where((r) => r.detail).toList(growable: false);
    final totals =
        widget.rows.where((r) => r.emphasize).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MovementConfirmationSurface(
          title: widget.title,
          amountLabel: widget.amountBtcLabel,
          supportingLabel: widget.fiatAmountLabel,
          compactRows: true,
          leading: party.isEmpty
              ? null
              : _PartySummaryCard(
                  destination: party,
                  network: network,
                  fromWallet: from,
                ),
          rows: [
            for (final row in summary)
              MovementConfirmationRow(
                label: row.label,
                value: row.value,
                numeric: row.numeric,
                technical: row.technical,
              ),
          ],
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ReviewDetailsSection(
            expanded: _detailsExpanded,
            rows: details,
            onToggle: () {
              HapticFeedback.selectionClick();
              setState(() => _detailsExpanded = !_detailsExpanded);
            },
          ),
        ],
        if (totals.isNotEmpty) ...[
          const SizedBox(height: 4),
          MovementConfirmationRows(
            compact: true,
            rows: [
              for (final row in totals)
                MovementConfirmationRow(
                  label: row.label,
                  value: row.value,
                  numeric: row.numeric,
                  technical: row.technical,
                  emphasize: true,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReviewDetailsSection extends StatelessWidget {
  final bool expanded;
  final List<SendPaymentReviewRowData> rows;
  final VoidCallback onToggle;

  const _ReviewDetailsSection({
    required this.expanded,
    required this.rows,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    SendMoneyCopy.reviewDetailsLabel(context),
                    style: AppTypography.inter(
                      color: _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          MovementConfirmationRows(
            compact: true,
            rows: [
              for (final row in rows)
                MovementConfirmationRow(
                  label: row.label,
                  value: row.value,
                  numeric: row.numeric,
                  technical: row.technical,
                  emphasize: row.emphasize,
                ),
            ],
          ),
      ],
    );
  }
}

class _PartySummaryCard extends StatelessWidget {
  final String destination;
  final String network;
  final String fromWallet;

  const _PartySummaryCard({
    required this.destination,
    required this.network,
    required this.fromWallet,
  });

  @override
  Widget build(BuildContext context) {
    final bare = destination.replaceAll('@', '').trim();
    final initial = bare.isEmpty ? '?' : bare[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _C.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: AppTypography.inter(
                color: _C.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (fromWallet.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    SendMoneyCopy.amountFromSubtitle(context, fromWallet),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.inter(
                      color: _C.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (network.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _C.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                network,
                style: AppTypography.inter(
                  color: _C.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
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
            onChanged: enabled
                ? (value) => onChanged(value ?? false)
                : null,
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
    return MovementConfirmationSurface(
      title: title,
      amountLabel: amountLabel,
      supportingLabel: subtitle,
      leading: const _ReceiptSuccessMark(),
      rows: [
        for (final row in rows)
          MovementConfirmationRow(
            label: row.label,
            value: row.value,
            numeric: row.numeric,
            technical: row.technical,
          ),
      ],
    );
  }
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
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: ready ? _C.button : _C.surfaceHigh.withValues(alpha: 0.64),
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                        key: ValueKey<bool>(isSubmitting),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSubmitting ? submittingLabel : label,
                            style: AppTypography.inter(
                              color: ready || isSubmitting
                                  ? _C.buttonText
                                  : _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.4,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSubmitting
                                ? KeroseneIcons.security
                                : KeroseneIcons.lock,
                            color: ready || isSubmitting
                                ? _C.buttonText
                                : _C.muted,
                            size: 16,
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
