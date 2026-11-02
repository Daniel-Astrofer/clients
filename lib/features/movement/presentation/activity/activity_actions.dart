import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/application/activity_cancel.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'transaction_presentation.dart';

enum _ActivityActionPhase { idle, choosing, cancelling, archiving }

/// Shared, account-bound actions for cards and persistent transaction details.
/// The record changes only after a matching cancellation acknowledgement; local
/// archiving changes visibility only after storage confirms every alias.
class ActivityActions extends ConsumerStatefulWidget {
  final Transaction transaction;
  final ValueChanged<Transaction>? onChanged;

  const ActivityActions({super.key, required this.transaction, this.onChanged});

  @override
  ConsumerState<ActivityActions> createState() => _ActivityActionsState();
}

class _ActivityActionsState extends ConsumerState<ActivityActions> {
  _ActivityActionPhase _phase = _ActivityActionPhase.idle;
  String? _error;
  String? _result;
  String? _resultScope;
  bool get _busy =>
      _phase != _ActivityActionPhase.idle &&
      _resultScope == ref.read(sessionStorageScopeProvider)?.trim();
  bool get _canCancel =>
      widget.transaction.cancellable &&
      !widget.transaction.isCancelled &&
      !widget.transaction.isConfirmed;

  bool _owns(Transaction tx, String scope) =>
      mounted &&
      widget.transaction.id == tx.id &&
      ref.read(sessionStorageScopeProvider)?.trim() == scope;

  @override
  void didUpdateWidget(covariant ActivityActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id) {
      _phase = _ActivityActionPhase.idle;
      _error = null;
      _result = null;
    }
  }

  Future<void> _perform({required bool archive}) async {
    if (_busy ||
        (archive ? !widget.transaction.isArchiveEligible : !_canCancel)) {
      return;
    }
    final scope = ref.read(sessionStorageScopeProvider)?.trim();
    if (scope == null || scope.isEmpty) {
      setState(() {
        _resultScope = scope;
        _error = context.tr.activityActionSessionRequired;
      });
      return;
    }
    final snapshot = widget.transaction;
    final tr = context.tr;
    final config = ref.read(moneyFormatConfigProvider);
    final rates = ref.read(resolvedBackendBtcRatesProvider);
    final summary = TransactionPresentation.fromTransaction(context, snapshot,
        displayCurrency: config.currency,
        appLocale: config.locale,
        btcDecimalPlaces: config.btcDecimalPlaces,
        btcUsd: rates?.btcUsd,
        btcEur: rates?.btcEur,
        btcBrl: rates?.btcBrl,
        includeExpandPayload: false);
    setState(() {
      _phase = _ActivityActionPhase.choosing;
      _error = null;
      _result = null;
      _resultScope = scope;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        animationStyle: AnimationStyle(
            duration: KeroseneMotion.duration(context, KeroseneMotion.short),
            reverseDuration:
                KeroseneMotion.duration(context, KeroseneMotion.short)),
        builder: (_) => _ActivityActionDialog(
            transaction: snapshot,
            summary: summary,
            archive: archive,
            scope: scope),
      );
      if (confirmed != true || !_owns(snapshot, scope)) return;
      if (archive ? !widget.transaction.isArchiveEligible : !_canCancel) {
        setState(() => _error = tr.activityActionChanged);
        return;
      }
      setState(() => _phase = archive
          ? _ActivityActionPhase.archiving
          : _ActivityActionPhase.cancelling);
      if (archive) {
        await archiveActivity(
            ref.read(activityArchiveProvider.notifier), snapshot);
        if (!mounted || !_owns(snapshot, scope)) return;
        setState(() => _result = tr.activityArchiveNowSuccess);
        AppNotice.showSuccess(context, message: tr.activityArchiveNowSuccess);
      } else {
        final updated = await cancelActivity(
            ref.read(transactionRepositoryProvider), snapshot);
        if (!mounted || !_owns(snapshot, scope)) return;
        if (widget.transaction.effectiveUpdatedAt
                .isAfter(updated.effectiveUpdatedAt) &&
            !widget.transaction.isCancelled) {
          setState(() => _error = tr.activityActionChanged);
          ref.invalidate(transactionHistoryProvider);
          ref.invalidate(paymentLinksProvider);
          return;
        }
        widget.onChanged?.call(updated);
        setState(() => _result = tr.txDetailCancelSuccess);
        AppNotice.showSuccess(context, message: tr.txDetailCancelSuccess);
      }
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(paymentLinksProvider);
    } catch (_) {
      if (!mounted || !_owns(snapshot, scope)) return;
      final message =
          archive ? tr.activityArchiveFailed : tr.txDetailCancelError;
      setState(() => _error = message);
      AppNotice.showError(context, message: message);
      if (!archive) {
        ref.invalidate(transactionHistoryProvider);
        ref.invalidate(paymentLinksProvider);
      }
    } finally {
      if (_owns(snapshot, scope)) {
        setState(() => _phase = _ActivityActionPhase.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = ref.watch(activityArchiveProvider);
    final scope = ref.watch(sessionStorageScopeProvider)?.trim();
    final canArchive = widget.transaction.isArchiveEligible &&
        !archived.contains(widget.transaction.id.trim());
    final showResult = scope == _resultScope;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showResult && (_error != null || _result != null))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KeroseneIcon(
                _error == null ? KeroseneIcons.success : KeroseneIcons.error,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_error ?? _result!,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ]),
        ),
      if (_canCancel)
        AppButton(
            key: const ValueKey('activity-cancel'),
            label: context.tr.txDetailCancelAction,
            variant: AppButtonVariant.secondary,
            expand: true,
            loading: showResult && _phase == _ActivityActionPhase.cancelling,
            onPressed: _busy ? null : () => _perform(archive: false)),
      if (canArchive) ...[
        if (_canCancel) const SizedBox(height: 12),
        AppButton(
            key: const ValueKey('activity-archive'),
            label: context.tr.activityArchiveNow,
            variant: AppButtonVariant.secondary,
            expand: true,
            loading: showResult && _phase == _ActivityActionPhase.archiving,
            onPressed: _busy ? null : () => _perform(archive: true)),
      ],
    ]);
  }
}

class _ActivityActionDialog extends ConsumerStatefulWidget {
  final Transaction transaction;
  final TransactionPresentation summary;
  final bool archive;
  final String scope;
  const _ActivityActionDialog(
      {required this.transaction,
      required this.summary,
      required this.archive,
      required this.scope});
  @override
  ConsumerState<_ActivityActionDialog> createState() =>
      _ActivityActionDialogState();
}

class _ActivityActionDialogState extends ConsumerState<_ActivityActionDialog> {
  bool _decided = false;
  bool _closing = false;
  void _close(bool confirmed) {
    if (_decided || ModalRoute.of(context)?.isCurrent != true) return;
    _decided = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionStorageScopeProvider)?.trim() != widget.scope) {
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final route = ModalRoute.of(context);
          if (route?.isActive == true) {
            Navigator.of(context).removeRoute(route!, false);
          }
        });
      }
      return const SizedBox.shrink();
    }
    final tr = context.tr;
    final theme = Theme.of(context);
    final tx = widget.transaction;
    final includesFees =
        tx.isDebit && (tx.showsNetworkFee || tx.showsServiceFee);
    String btc(int sats) => MoneyDisplay.formatOperationAmount(
        satoshis: sats, appLocale: Localizations.localeOf(context));
    Widget row(String label, String value, {bool technical = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            SelectableText(value,
                textDirection: technical ? TextDirection.ltr : null,
                style: technical
                    ? AppTypography.technicalMono(
                        color: theme.colorScheme.onSurface, fontSize: 12)
                    : theme.textTheme.bodyMedium),
          ]),
        );
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeroseneIcon(
                    widget.archive
                        ? KeroseneIcons.archive
                        : KeroseneIcons.warning,
                    size: 28),
                const SizedBox(height: 12),
                Text(
                    widget.archive
                        ? tr.activityArchiveTitle
                        : tr.txDetailCancelTitle,
                    style: AppTypography.bodyLarge.copyWith(
                        fontSize: 20, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 12),
                row(tr.txListStatus, widget.summary.statusLabel),
                row(
                    tr.txListAmount,
                    includesFees
                        ? btc(
                            tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis)
                        : widget.summary.primaryAmountLabel),
                if (!includesFees &&
                    !widget.summary.primaryAmountLabel.contains('BTC'))
                  row(tr.txListAmountBtc, btc(tx.amountSatoshis)),
                if (tx.showsNetworkFee)
                  row(tr.txListNetworkFee, btc(tx.feeSatoshis)),
                if (tx.showsServiceFee)
                  row(tr.txListServiceFee, btc(tx.serviceFeeSatoshis)),
                if (includesFees)
                  row(tr.movementOperationTotal,
                      widget.summary.primaryAmountLabel),
                row(tr.txListId, widget.transaction.id, technical: true),
                if (widget.transaction.toAddress.trim().isNotEmpty)
                  row(tr.txListToAddress, widget.transaction.toAddress,
                      technical: true),
                const SizedBox(height: 12),
                Text(
                    widget.archive
                        ? tr.activityArchiveEffect
                        : tr.txDetailCancelBody,
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          )),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                        key: const ValueKey('activity-confirm-action'),
                        label: widget.archive
                            ? tr.activityArchiveConfirm
                            : tr.txDetailCancelConfirm,
                        expand: true,
                        onPressed: () => _close(true)),
                    const SizedBox(height: 12),
                    AppButton(
                        label: tr.goBack,
                        expand: true,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _close(false)),
                  ])),
        ]),
      ),
    );
  }
}
