import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/features/movement/providers/payment_submission_recovery_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show lastTransactionHistoryProvider;

/// Visible recovery belongs to the account's activity, not to a success toast.
class PaymentRecoveryPanel extends ConsumerWidget {
  const PaymentRecoveryPanel({super.key, this.showAll = false});
  final bool showAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(sessionStorageScopeProvider);
    if (scope == null) return const SizedBox.shrink();
    final records = ref.watch(pendingPaymentSubmissionsProvider(scope));
    return records.when(
      skipLoadingOnReload: true,
      data: (values) {
        if (values.isEmpty) {
          return showAll
              ? Text(context.tr.recoverySubmissionEmpty,
                  style: AppTypography.bodyMedium)
              : const SizedBox.shrink();
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showAll) ...[
                Text(context.tr.recoverySubmissionTitle,
                    style: AppTypography.h3Small),
                const SizedBox(height: 12),
              ],
              for (final record in showAll ? values : values.take(3))
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecoveryCard(
                        key: ValueKey('$scope:${record.key}'),
                        scope: scope,
                        record: record)),
              if (!showAll && values.length > 3)
                TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                        keroseneHorizontalRoute<void>(
                            builder: (_) => const PaymentRecoveryScreen())),
                    child: Text(context.tr.viewAll)),
            ]);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => HomeGlassPanel(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr.recoverySubmissionStorage,
                style: AppTypography.bodyMedium),
            TextButton(
                onPressed: () =>
                    ref.invalidate(pendingPaymentSubmissionsProvider(scope)),
                child: Text(context.tr.tryAgain)),
          ])),
    );
  }
}

class PaymentRecoveryScreen extends StatelessWidget {
  const PaymentRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr.recoverySubmissionTitle)),
        body: const SafeArea(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: PaymentRecoveryPanel(showAll: true))),
      );
}

class _RecoveryCard extends ConsumerStatefulWidget {
  const _RecoveryCard({super.key, required this.record, required this.scope});
  final String scope;
  final PaymentSubmission record;
  @override
  ConsumerState<_RecoveryCard> createState() => _RecoveryCardState();
}

class _RecoveryCardState extends ConsumerState<_RecoveryCard> {
  bool _opening = false;
  bool _storageFailed = false;

  Future<void> _open(Transaction operation) async {
    if (_opening) return;
    final scope = ref.read(sessionStorageScopeProvider);
    if (scope == null || scope != widget.scope) return;
    setState(() {
      _opening = true;
      _storageFailed = false;
    });
    final money = MovementMoney.fromJournal(widget.record.display);
    final copy = TransactionPresentationCopy.of(context);
    final label = _statusLabel(copy, operation.displayStatus);
    final rows = <SendPaymentReceiptRowData>[
      SendPaymentReceiptRowData(
          label: context.tr.sendReviewWallet,
          value: operation.sourceWalletLabel ??
              operation.walletLabel ??
              compactSendReceiptValue(widget.record.walletId)),
      SendPaymentReceiptRowData(
          label: context.tr.sendReviewDestination,
          value: compactSendReceiptValue(operation.toAddress.isNotEmpty
              ? operation.toAddress
              : widget.record.destination)),
      if (operation.showsNetworkFee)
        SendPaymentReceiptRowData(
            label: context.tr.sendReviewNetworkFee,
            value: money.primary(operation.feeBTC),
            secondaryValue: money.secondary(operation.feeBTC),
            numeric: true,
            kind: SendPaymentReceiptRowKind.networkFee),
      if (operation.showsServiceFee)
        SendPaymentReceiptRowData(
            label: context.tr.sendReviewKeroseneFee,
            value: money.primary(operation.serviceFeeBTC),
            secondaryValue: money.secondary(operation.serviceFeeBTC),
            numeric: true,
            kind: SendPaymentReceiptRowKind.platformFee),
      SendPaymentReceiptRowData(
          label: context.tr.sendReviewStatus,
          value: label,
          kind: SendPaymentReceiptRowKind.status),
    ];
    try {
      await Navigator.of(context).push<void>(keroseneHorizontalRoute<void>(
          builder: (_) => SendPaymentReceiptScreen<void>(
              result: null,
              data: SendPaymentReceiptData(
                  title: label,
                  subtitle: context.tr.recoverySubmissionPending,
                  amountLabel: money.primary(operation.amountBTC),
                  secondaryAmountLabel: money.secondary(operation.amountBTC),
                  money: money,
                  occurredAt: operation.timestamp,
                  updatedAt: operation.effectiveUpdatedAt,
                  confirmed:
                      operation.displayStatus == TransactionStatus.confirmed,
                  transactionId: operation.id,
                  rows: rows,
                  shareText: label))));
      if (!mounted || ref.read(sessionStorageScopeProvider) != scope) return;
      final store = ref.read(paymentSubmissionStoreProvider);
      await store.acknowledge(scope, widget.record.key,
          resolvedTransactionId: operation.id);
    } catch (_) {
      if (mounted) setState(() => _storageFailed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionStorageScopeProvider) != widget.scope) {
      return const SizedBox.shrink();
    }
    final identity =
        (widget.scope, widget.record.key, widget.record.transactionId);
    final lookup = ref.watch(paymentSubmissionLookupProvider(identity));
    final fromHistory = ref.watch(lastTransactionHistoryProvider.select(
        (rows) => rows
            .where((item) => item.id == widget.record.transactionId)
            .firstOrNull));
    final resolved = lookup.asData?.value;
    final operation = fromHistory != null &&
            (resolved == null ||
                !fromHistory.effectiveUpdatedAt
                    .isBefore(resolved.effectiveUpdatedAt))
        ? fromHistory
        : resolved;
    final money = MovementMoney.fromJournal(widget.record.display);
    final status = operation == null
        ? context.tr.recoverySubmissionPending
        : _statusLabel(
            TransactionPresentationCopy.of(context), operation.displayStatus);
    final amount =
        operation?.amountBTC ?? widget.record.amountSats / 100000000.0;
    return HomeGlassPanel(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (lookup.isLoading && operation == null)
            const LinearProgressIndicator(minHeight: 2),
          Text(money.primary(amount), style: AppTypography.h3Small),
          if (money.secondary(amount).isNotEmpty)
            Text(money.secondary(amount), style: AppTypography.bodySmall),
          const SizedBox(height: 8),
          Text(status, style: AppTypography.bodyMedium),
          if (lookup.hasError)
            Text(context.tr.recoverySubmissionUnavailable,
                style: AppTypography.bodySmall),
          if (_storageFailed)
            Text(context.tr.recoverySubmissionStorage,
                style: AppTypography.bodySmall
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          TextButton(
              onPressed: _opening
                  ? null
                  : operation != null
                      ? () => _open(operation)
                      : lookup.isLoading
                          ? null
                          : () => ref.invalidate(
                              paymentSubmissionLookupProvider(identity)),
              child: Text(operation != null
                  ? context.tr.receiptViewOperation
                  : context.tr.recoverySubmissionVerify)),
        ]));
  }
}

String _statusLabel(
        TransactionPresentationCopy copy, TransactionStatus status) =>
    switch (status) {
      TransactionStatus.pending => copy.pending,
      TransactionStatus.confirming => copy.confirming,
      TransactionStatus.confirmed => copy.confirmed,
      TransactionStatus.failed => copy.failed,
      TransactionStatus.cancelled => copy.cancelled,
      TransactionStatus.reconciling => copy.needsReview,
    };
