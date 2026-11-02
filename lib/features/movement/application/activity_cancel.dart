import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';

/// Shared cancel routing for history rows and payment-link synthetics.
Future<Transaction> cancelActivity(
  TransactionRepository repo,
  Transaction current,
) async {
  final target = (current.cancelTarget ?? '').trim().toUpperCase();
  final isPaymentRequest = target == 'PAYMENT_REQUEST' ||
      current.isPaymentLink ||
      current.id.startsWith('pl_');
  if (isPaymentRequest) {
    final requestId = (current.paymentRequestPublicId ??
            current.paymentRequestId ??
            (current.id.startsWith('pl_')
                ? current.id.substring(3)
                : current.id))
        .trim();
    if (requestId.isEmpty) {
      throw StateError('payment request id missing');
    }
    final link = await repo.cancelPaymentRequest(requestId);
    if (link.id.trim() != requestId || !link.isCancelled) {
      throw StateError('Cancellation not confirmed');
    }
    final updated = link.toTransaction();
    if (!updated.isCancelled) throw StateError('Cancellation not confirmed');
    return updated.id == current.id
        ? updated
        : Transaction.fromJson({
            ...updated.toJson(),
            'id': current.id,
          });
  }
  final transactionId = current.id.trim();
  if (transactionId.isEmpty) throw StateError('Transaction identifier missing');
  final updated = await repo.cancelTransaction(transactionId);
  if (updated.id.trim() != current.id.trim() || !updated.isCancelled) {
    throw StateError('Cancellation not confirmed');
  }
  return updated;
}

/// Archive both the history row id and the payment-link strip key when needed.
Future<void> archiveActivity(
  ActivityArchiveNotifier archive,
  Transaction tx,
) async {
  if (!tx.isArchiveEligible) throw StateError('Activity cannot be archived');
  final id = tx.id.trim();
  if (id.isEmpty) throw StateError('Activity identifier missing');
  final keys = {id};
  final prId = (tx.paymentRequestPublicId ?? tx.paymentRequestId ?? '').trim();
  if (prId.isNotEmpty) {
    keys.add(paymentLinkArchiveId(prId));
  } else if (id.startsWith('pl_') && id.substring(3).trim().isNotEmpty) {
    keys.add(paymentLinkArchiveId(id.substring(3)));
  }
  await archive.markArchivedMany(keys);
}
