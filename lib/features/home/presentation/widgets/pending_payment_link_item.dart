import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/movement/domain/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/widgets/activity_glyph.dart';

/// Compact home/strip card for a payment request.
///
/// Pending: open + cancel. Cancelled/expired: open + archive now.
class PendingPaymentLinkItem extends ConsumerStatefulWidget {
  final PaymentLink paymentLink;
  final VoidCallback? onTap;

  const PendingPaymentLinkItem({
    super.key,
    required this.paymentLink,
    this.onTap,
  });

  @override
  ConsumerState<PendingPaymentLinkItem> createState() =>
      _PendingPaymentLinkItemState();
}

class _PendingPaymentLinkItemState
    extends ConsumerState<PendingPaymentLinkItem> {
  bool _busy = false;

  PaymentLink get paymentLink => widget.paymentLink;

  bool get _isCompleted => paymentLink.isCompleted || paymentLink.isPaid;

  bool get _isExpired {
    if (paymentLink.isExpired && !_isCompleted) return true;
    final expiresAt = paymentLink.expiresAt;
    if (expiresAt == null || _isCompleted || paymentLink.isCancelled) {
      return false;
    }
    return expiresAt.isBefore(DateTime.now());
  }

  bool get _isCancelled => paymentLink.isCancelled;

  bool get _canCancel =>
      !_isCompleted && !_isCancelled && !_isExpired && !_busy;

  bool get _canArchiveNow =>
      (_isCancelled || _isExpired) && !_isCompleted && !_busy;

  Future<void> _confirmAndCancel() async {
    if (!_canCancel) return;
    final tr = context.tr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.receivePaymentLinkCancelTitle),
        content: Text(tr.receivePaymentLinkCancelMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr.receivePaymentLinkConfirmCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .cancelPaymentRequest(paymentLink.id);
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr.receivePaymentLinkCancelled),
          action: SnackBarAction(
            label: tr.activityArchiveNow,
            onPressed: () {
              unawaited(_archiveNow(silent: true));
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.txDetailCancelError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveNow({bool silent = false}) async {
    if (_busy && !silent) return;
    setState(() => _busy = true);
    try {
      await ref.read(activityArchiveProvider.notifier).markArchived(
            paymentLinkArchiveId(paymentLink.id),
          );
      // Also archive synthetic history id so the feed matches the strip.
      await ref.read(activityArchiveProvider.notifier).markArchived(
            'pl_${paymentLink.id.trim()}',
          );
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.activityArchiveNowSuccess)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final timeLeft = paymentLink.expiresAt != null
        ? paymentLink.expiresAt!.difference(DateTime.now())
        : Duration.zero;

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final error = Theme.of(context).colorScheme.error;

    final statusLabel = _isCompleted
        ? tr.paymentLinkStatusReceived
        : (_isExpired
            ? tr.paymentLinkStatusExpired
            : (_isCancelled
                ? tr.financialStatementFilterCancelled
                : tr.paymentLinkStatusPending));

    final kindLabel = _isCompleted
        ? (paymentLink.isLightningPaymentRequest
            ? tr.paymentLinkPaidLightning
            : tr.paymentLinkConfirmed)
        : (paymentLink.isLightningPaymentRequest
            ? tr.paymentLinkKindLightning
            : tr.paymentLinkKindOnchain);

    final description = paymentLink.description.isNotEmpty
        ? paymentLink.description
        : (paymentLink.isLightningPaymentRequest
            ? tr.paymentLinkAwaitingLightning
            : tr.paymentLinkAwaitingOnchain);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: KeroseneMotion.medium,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        width: 280,
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isExpired || _isCancelled
                ? error.withValues(alpha: 0.35)
                : onSurface.withValues(alpha: 0.20),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ActivityGlyph.forPaymentLink(paymentLink, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel.toUpperCase(),
                        style: TextStyle(
                          color: _isExpired || _isCancelled
                              ? error
                              : onSurface.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (!_isCompleted && !_isExpired && !_isCancelled)
                        Text(
                          _formatDuration(timeLeft),
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tr.paymentLinkAmountLabel.toUpperCase(),
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.24),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      paymentLink.amountBtc.toStringAsFixed(8),
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: AppTypography.financialFontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    kindLabel,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.2),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_canCancel)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            unawaited(_confirmAndCancel());
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: error,
                            ),
                          )
                        : Text(
                            tr.txDetailCancelAction,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  )
                else if (_canArchiveNow)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            unawaited(_archiveNow());
                          },
                    icon: Icon(KeroseneIcons.archive, size: 14, color: onSurface),
                    label: Text(
                      tr.activityArchiveNow,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  Icon(
                    KeroseneIcons.chevronRight,
                    size: 12,
                    color: onSurface.withValues(alpha: 0.2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0m 0s';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
