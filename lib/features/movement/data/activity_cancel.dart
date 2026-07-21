import 'package:kerosene/features/movement/data/activity_archive_store.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
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
    return link.toTransaction();
  }
  return repo.cancelTransaction(current.id);
}

/// Archive both the history row id and the payment-link strip key when needed.
Future<void> archiveActivity(
  ActivityArchiveNotifier archive,
  Transaction tx,
) async {
  final id = tx.id.trim();
  if (id.isNotEmpty) {
    await archive.markArchived(id);
  }
  final prId = (tx.paymentRequestPublicId ?? tx.paymentRequestId ?? '').trim();
  if (prId.isNotEmpty) {
    await archive.markArchived(paymentLinkArchiveId(prId));
    return;
  }
  if (id.startsWith('pl_')) {
    final bare = id.substring(3).trim();
    if (bare.isNotEmpty) {
      await archive.markArchived(paymentLinkArchiveId(bare));
    }
  }
}
