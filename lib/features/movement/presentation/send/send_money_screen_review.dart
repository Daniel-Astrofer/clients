import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/core/logging/app_log.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_surface_provider.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
// architecture-allow-large-file: review and authorization composition preserve
// the deferred route and external confirmation callback contracts.
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/presentation/send/send_amount_step.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/components/generic/kerosene_education_dialog.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';

import 'send_money_screen_dependencies.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';

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

enum SendPaymentReceiptRowKind {
  information,
  networkFee,
  platformFee,
  total,
  status,
  networkReference
}

class SendPaymentReceiptRowData {
  final String label;
  final String value;
  final String secondaryValue;
  final bool numeric;
  final bool technical;
  final SendPaymentReceiptRowKind kind;

  const SendPaymentReceiptRowData({
    required this.label,
    required this.value,
    this.secondaryValue = '',
    this.numeric = false,
    this.technical = false,
    this.kind = SendPaymentReceiptRowKind.information,
  });
}

class SendPaymentReceiptData {
  final String title;
  final String subtitle;
  final String amountLabel;
  final String secondaryAmountLabel;
  final DateTime? occurredAt;
  final DateTime? updatedAt;
  final bool confirmed;
  final String? transactionId;
  final List<SendPaymentReceiptRowData> rows;
  final String shareText;
  final MovementMoney? money;

  const SendPaymentReceiptData({
    required this.title,
    this.subtitle = '',
    required this.amountLabel,
    this.secondaryAmountLabel = '',
    required this.occurredAt,
    this.updatedAt,
    this.confirmed = true,
    this.transactionId,
    required this.rows,
    required this.shareText,
    this.money,
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
  final ValueChanged<bool>? onSubmittingChanged;

  /// Locked payment-request: speed / fee chips (amount is not editable).
  final bool showFeeTierControls;
  final NetworkFeeTier? feeTier;
  final ValueChanged<NetworkFeeTier>? onFeeTierChanged;

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
    this.onSubmittingChanged,
    this.showFeeTierControls = false,
    this.feeTier,
    this.onFeeTierChanged,
  });

  @override
  State<InternalTransferReviewScreen<T>> createState() =>
      InternalTransferReviewScreenState<T>();
}

class InternalTransferReviewScreenState<T>
    extends State<InternalTransferReviewScreen<T>> {
  bool _isSubmitting = false;
  bool _firstSendAcknowledged = false;
  bool _accepted = false;

  bool get _canAuthorize {
    if (_isSubmitting || _accepted) return false;
    if (widget.requiresFirstSendAck && !_firstSendAcknowledged) return false;
    return true;
  }

  Future<void> _confirm() async {
    if (!_canAuthorize || _isSubmitting) return;
    HapticFeedback.mediumImpact();
    widget.onSubmittingChanged?.call(true);
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await widget.onConfirm(context);
      if (!mounted) return;
      if (result != null && result != false) {
        _accepted = true;
        final receipt = widget.receiptBuilder?.call(result);
        if (receipt != null) {
          await Navigator.of(context).push<T>(keroseneHorizontalRoute<T>(
            builder: (_) =>
                SendPaymentReceiptScreen<T>(data: receipt, result: result),
          ));
          if (!mounted) return;
        }
        _finishWithResult(result);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr.tryAgain)));
    } finally {
      widget.onSubmittingChanged?.call(false);
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        ? SendMoneyCopy.authorizingAction(context)
        : widget.submittingLabel;

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: _cBackground,
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
                                      if (widget.showFeeTierControls &&
                                          widget.feeTier != null &&
                                          widget.onFeeTierChanged != null) ...[
                                        const SizedBox(height: 20),
                                        Text(
                                          context.tr.sendSpeedTitle,
                                          textAlign: TextAlign.center,
                                          style: AppTypography.inter(
                                            color: _cMuted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr.sendFixedAmountNotice,
                                          textAlign: TextAlign.center,
                                          style: AppTypography.inter(
                                            color: _cMuted.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SendFeeTierBar(
                                          selected: widget.feeTier!,
                                          onSelected: _isSubmitting
                                              ? (_) {}
                                              : widget.onFeeTierChanged!,
                                        ),
                                      ],
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
                                            setState(
                                              () => _firstSendAcknowledged =
                                                  value,
                                            );
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
                  color: _cBackground.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _cText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          submittingLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.inter(
                            color: _cText,
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

class SendPaymentReceiptScreen<T> extends ConsumerStatefulWidget {
  final SendPaymentReceiptData data;
  final T result;

  const SendPaymentReceiptScreen({
    super.key,
    required this.data,
    required this.result,
  });

  @override
  ConsumerState<SendPaymentReceiptScreen<T>> createState() =>
      _SendPaymentReceiptScreenState<T>();
}

class _SendPaymentReceiptScreenState<T>
    extends ConsumerState<SendPaymentReceiptScreen<T>>
    with FinancialSurfaceMixin {
  bool _opening = false;
  String? _visibleShareText;
  String? _visibleTitle;
  Transaction? _latestOperation;
  String? _receiptScope;
  @override
  void initState() {
    super.initState();
    final id = widget.data.transactionId;
    if (id != null && PaymentSubmissionStore.validTransactionId(id)) {
      _receiptScope = ref.read(sessionStorageScopeProvider);
    }
  }

  void _close() {
    final scope = _receiptScope;
    final id = widget.data.transactionId;
    if (scope != null &&
        id != null &&
        ref.read(sessionStorageScopeProvider) == scope) {
      unawaited(ref
          .read(paymentSubmissionStoreProvider)
          .acknowledgeTransaction(scope, id)
          .catchError((Object _) {
        appLog(
            'Payment receipt was viewed; its recovery acknowledgment could not be saved.');
      }));
    }
    Navigator.of(context).pop(widget.result);
  }

  Future<void> _shareReceipt() async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: _visibleShareText ?? widget.data.shareText,
        subject: _visibleTitle ?? widget.data.title,
      ));
    } catch (_) {
      if (mounted) SnackbarHelper.showError(context.tr.tryAgain);
    }
  }

  Future<void> _openOperation() async {
    final id = widget.data.transactionId;
    if (id == null || _opening) return;
    setState(() => _opening = true);
    try {
      final result =
          await ref.read(ledgerRepositoryProvider).getTransactionById(id);
      if (!mounted) return;
      final operation = result.fold((_) => null, (value) => value);
      if (operation != null) {
        await TransactionDetailScreen.open(context, operation);
      } else {
        SnackbarHelper.showError(context.tr.tryAgain);
      }
    } catch (_) {
      if (mounted) SnackbarHelper.showError(context.tr.tryAgain);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = ref.watch(lastTransactionHistoryProvider.select(
        (history) => history
            .where((item) => item.id == widget.data.transactionId)
            .firstOrNull));
    final minimumUpdate =
        _latestOperation?.effectiveUpdatedAt ?? widget.data.updatedAt;
    if (candidate != null &&
        (minimumUpdate == null ||
            !candidate.effectiveUpdatedAt.isBefore(minimumUpdate))) {
      _latestOperation = candidate;
    }
    final operation = _latestOperation;
    final status = operation?.displayStatus;
    final confirmed = operation == null
        ? widget.data.confirmed
        : status == TransactionStatus.confirmed;
    final copy = TransactionPresentationCopy.of(context);
    final statusLabel = operation == null
        ? null
        : switch (operation.displayStatus) {
            TransactionStatus.confirmed => copy.confirmed,
            TransactionStatus.confirming => copy.confirming,
            TransactionStatus.failed => copy.failed,
            TransactionStatus.cancelled => copy.cancelled,
            TransactionStatus.reconciling => copy.needsReview,
            TransactionStatus.pending => copy.pending,
          };
    final title = switch (status) {
      TransactionStatus.failed => copy.failed,
      TransactionStatus.cancelled => copy.cancelled,
      TransactionStatus.reconciling => copy.needsReview,
      _ => confirmed
          ? SendMoneyCopy.receiptTitleConfirmed(context)
          : widget.data.title,
    };
    final subtitle = switch (status) {
      TransactionStatus.failed => context.tr.receiptFailedSubtitle,
      TransactionStatus.cancelled => context.tr.receiptCancelledSubtitle,
      TransactionStatus.reconciling => context.tr.receiptReconcilingSubtitle,
      _ => confirmed
          ? SendMoneyCopy.receiptSubtitleConfirmed(context)
          : widget.data.subtitle,
    };
    final money = widget.data.money;
    final liveMoney = operation != null && money != null;
    final amountLabel = liveMoney
        ? money.primarySatoshis(operation.amountSatoshis)
        : widget.data.amountLabel;
    final secondaryAmountLabel = liveMoney
        ? money.secondary(operation.amountBTC)
        : widget.data.secondaryAmountLabel;
    final occurredAt = operation?.timestamp ?? widget.data.occurredAt;
    final networkReference = [operation?.blockchainTxid, operation?.paymentHash]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final rows = <SendPaymentReceiptRowData>[
      if (occurredAt != null)
        SendPaymentReceiptRowData(
          label: SendMoneyCopy.receiptDateLabel(context),
          value: _formatReceiptDate(context, occurredAt),
          numeric: true,
        ),
      for (final row in widget.data.rows)
        if (!(operation != null &&
                (row.kind == SendPaymentReceiptRowKind.status ||
                    row.label == context.tr.sendReviewStatus)) &&
            !(liveMoney &&
                {
                  SendPaymentReceiptRowKind.networkFee,
                  SendPaymentReceiptRowKind.platformFee,
                  SendPaymentReceiptRowKind.total
                }.contains(row.kind)) &&
            !(networkReference != null &&
                row.kind == SendPaymentReceiptRowKind.networkReference))
          row,
      if (liveMoney && operation.showsNetworkFee)
        SendPaymentReceiptRowData(
            label: context.tr.sendReviewNetworkFee,
            value: money.primarySatoshis(operation.feeSatoshis),
            secondaryValue: money.secondary(operation.feeBTC),
            numeric: true,
            kind: SendPaymentReceiptRowKind.networkFee),
      if (liveMoney && operation.showsServiceFee)
        SendPaymentReceiptRowData(
            label: context.tr.sendReviewKeroseneFee,
            value: money.primarySatoshis(operation.serviceFeeSatoshis),
            secondaryValue: money.secondary(operation.serviceFeeBTC),
            numeric: true,
            kind: SendPaymentReceiptRowKind.platformFee),
      if (liveMoney &&
          status != TransactionStatus.failed &&
          status != TransactionStatus.cancelled)
        SendPaymentReceiptRowData(
            label: confirmed
                ? context.tr.sendReviewTotalDebited
                : context.tr.receiptExpectedTotal,
            value: money.primarySatoshis(operation.signedDisplaySatoshis),
            secondaryValue:
                money.secondary(operation.signedDisplaySatoshis / 100000000.0),
            numeric: true,
            kind: SendPaymentReceiptRowKind.total),
      if (networkReference != null && networkReference.trim().isNotEmpty)
        SendPaymentReceiptRowData(
            label: context.tr.sendReviewTxId,
            value: compactSendReceiptValue(networkReference, head: 10, tail: 8),
            technical: true,
            kind: SendPaymentReceiptRowKind.networkReference),
      if (operation != null)
        SendPaymentReceiptRowData(
          label: context.tr.sendReviewStatus,
          value: statusLabel!,
          kind: SendPaymentReceiptRowKind.status,
        ),
      if (operation != null && operation.showsOnchainConfirmations)
        SendPaymentReceiptRowData(
          label: context.tr.confirming,
          value:
              '${operation.confirmations} / ${operation.onchainConfirmationTarget}',
        ),
    ];

    _visibleShareText = [
      title,
      amountLabel,
      if (secondaryAmountLabel.isNotEmpty) secondaryAmountLabel,
      for (final row in rows)
        '${row.label}: ${row.value}${row.secondaryValue.isEmpty ? '' : ' (${row.secondaryValue})'}'
    ].join('\n');
    _visibleTitle = title;
    return Scaffold(
      backgroundColor: _cBackground,
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
                      confirmed: confirmed,
                      status: status,
                      title: title,
                      subtitle: subtitle,
                      amountLabel: amountLabel,
                      secondaryAmountLabel: secondaryAmountLabel,
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
                      if (widget.data.transactionId != null) ...[
                        TextButton(
                            onPressed: _opening ? null : _openOperation,
                            child: Text(context.tr.receiptViewOperation)),
                        const SizedBox(height: 10),
                      ],
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

  const _ReviewBody({required this.title, required this.card, this.onBack});

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
              icon: const KeroseneIcon(KeroseneIcons.back, size: 31),
              style: IconButton.styleFrom(
                foregroundColor: _cText,
                disabledForegroundColor: _cMuted.withValues(alpha: 0.38),
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
                style: HomeTypography.heroTitle(
                  color: _cText,
                  fontSize: 30.94,
                ).copyWith(height: 1.61, letterSpacing: -0.2),
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
                color: _cBackground,
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
                            color: _cBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: KeroseneIcon(icon, color: _cText, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.recipientName,
                                style: AppTypography.inter(
                                  color: _cText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              if (showAddress) ...[
                                const SizedBox(height: 4),
                                SelectableText(
                                  card.recipientAddress,
                                  style: AppTypography.technicalMono(
                                    color: _cMuted,
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

  const _ReviewLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            style: AppTypography.inter(
              color: _cText,
              fontSize: 12.6,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
            flex: 2,
            child: Text(
              value,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.right,
              style: AppTypography.inter(
                color: _cText,
                fontSize: 12.6,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            )),
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
            maxLines: 2,
            style: AppTypography.inter(
              color: _cText,
              fontSize: emphasize ? 13.5 : 12.6,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.right,
                      style: AppTypography.amountLarge.copyWith(
                        color: _cText,
                        fontSize: emphasize ? 16.2 : 14.4,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    )),
                if (fiat.trim().isNotEmpty) ...[
                  const SizedBox(height: 6.5),
                  Text(
                    fiat,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.right,
                    style: AppTypography.inter(
                      color: _cText,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            )),
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
          color: _cMuted,
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
                  color: _cText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  decoration: TextDecoration.underline,
                  decorationColor: _cText.withValues(alpha: 0.55),
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
        color: _cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            SendMoneyCopy.firstSendAckTitle(context),
            style: AppTypography.inter(
              color: _cText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SendMoneyCopy.firstSendAckBody(context),
            style: AppTypography.inter(
              color: _cSecondary,
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
                color: _cText,
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
            activeColor: _cText,
            checkColor: _cBackground,
            side: BorderSide(color: _cBorder, width: 1.4),
            title: Text(
              SendMoneyCopy.firstSendAckCheckbox(context),
              style: AppTypography.inter(
                color: _cText,
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
  final bool confirmed;
  final TransactionStatus? status;
  final String title;
  final String subtitle;
  final String amountLabel;
  final String secondaryAmountLabel;
  final List<SendPaymentReceiptRowData> rows;

  const _ReceiptBody({
    required this.confirmed,
    this.status,
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    this.secondaryAmountLabel = '',
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
            _ReceiptSuccessMark(confirmed: confirmed, status: status),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.playfairDisplay(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amountLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.amount.copyWith(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                )),
            if (secondaryAmountLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(secondaryAmountLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.number.copyWith(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0)),
            ],
            const SizedBox(height: 32),
            const Divider(color: Colors.black12, height: 1, thickness: 1),
            const SizedBox(height: 24),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row.technical
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(row.label,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.black54,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 6),
                          SelectableText(
                            row.value,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.technicalMono(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.black54,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  row.value,
                                  textAlign: TextAlign.right,
                                  style: (row.numeric
                                          ? AppTypography.number
                                          : AppTypography.bodyMedium)
                                      .copyWith(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                      )
                                      .copyWith(
                                        fontFeatures: row.numeric
                                            ? const [
                                                FontFeature.tabularFigures()
                                              ]
                                            : null,
                                      ),
                                ),
                                if (row.secondaryValue.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    row.secondaryValue,
                                    textAlign: TextAlign.right,
                                    style: AppTypography.number.copyWith(
                                      color: Colors.black54,
                                      fontSize: 13,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ],
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
      ..color = AppColors.hexFFF9F6F0 // Paper color
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
          icon: const KeroseneIcon(KeroseneIcons.close, size: 22),
          style: IconButton.styleFrom(
            foregroundColor: _cMuted,
            disabledForegroundColor: _cMuted.withValues(alpha: 0.38),
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
              color: ready ? _cText : _cSurfaceHigh.withValues(alpha: 0.64),
              border: Border.all(color: ready ? _cText : _cBorder),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AnimatedSwitcher(
                      duration: KeroseneMotion.duration(
                        context,
                        KeroseneMotion.short,
                      ),
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
                                  ? _cBackground
                                  : _cMuted,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          KeroseneIcon(
                            isSubmitting
                                ? KeroseneIcons.security
                                : KeroseneIcons.lock,
                            color:
                                ready || isSubmitting ? _cBackground : _cMuted,
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
  final bool confirmed;
  final TransactionStatus? status;
  const _ReceiptSuccessMark({required this.confirmed, this.status});

  @override
  Widget build(BuildContext context) {
    final needsAttention = status == TransactionStatus.failed ||
        status == TransactionStatus.reconciling;
    // This mark is drawn on receipt paper, independent of the app's theme.
    const color = Colors.black87;
    final icon = confirmed
        ? KeroseneIcons.check
        : needsAttention
            ? KeroseneIcons.warning
            : status == TransactionStatus.cancelled
                ? KeroseneIcons.close
                : KeroseneIcons.pending;
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: KeroseneIcon(icon, color: color, size: 34),
      ),
    );
  }
}

class _ReceiptPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ReceiptPrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _cText,
          foregroundColor: _cBackground,
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

  const _ReceiptShareButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _cText,
          side: BorderSide(color: _cBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        icon: const KeroseneIcon(KeroseneIcons.share, size: 17),
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
  // Keep the compatibility signature; financial identifiers are never shortened.
  return value.trim();
}

String _formatReceiptDate(BuildContext context, DateTime value) {
  value = AppDateTime.inDisplayZone(context, value);
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

/// Review palette — redirects to [SendFlowTheme] so send and receive share
/// one color language.  File-scope getters are kept for minimal diff.
SendFlowTheme _reviewTokens() => SendFlowTheme.forVariant(
      ThemeTokenBridge.isLight ? Brightness.light : Brightness.dark,
    );

Color get _cBackground => _reviewTokens().background;
Color get _cSurface => _reviewTokens().surface;
Color get _cSurfaceHigh => _reviewTokens().surfaceHigh;
Color get _cBorder => _reviewTokens().border;
Color get _cText => _reviewTokens().textPrimary;
Color get _cSecondary => _reviewTokens().textSecondary;
Color get _cMuted => _reviewTokens().textMuted;
