import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import 'entities/payment_link.dart';
import 'repositories/transaction_repository.dart';

class CreatePaymentLinkUseCase {
  final TransactionRepository repository;

  CreatePaymentLinkUseCase(this.repository);

  Future<Either<Failure, PaymentLink>> call({
    required double amount,
    required String receiverWalletName,
    String rail = 'ONCHAIN',
    String? walletId,
  }) async {
    try {
      final normalizedRail = rail.trim().toUpperCase();
      final result = await repository.createPaymentLink(
        amount: amount,
        description: 'Recebimento $receiverWalletName',
        expiresInMinutes: 60,
        visibility: 'PRIVATE',
        confirmationMode: 'USER_ACTION_REQUIRED',
        amountLocked: true,
        referenceLabel: receiverWalletName,
        metadata: {
          'walletName': receiverWalletName,
          if (walletId != null && walletId.trim().isNotEmpty)
            'walletId': walletId.trim(),
          'rail': normalizedRail.isEmpty ? 'ONCHAIN' : normalizedRail,
          'source': 'receive_flow',
        },
      );

      return Right(result);
    } catch (error) {
      return Left(UnknownFailure(message: error.toString()));
    }
  }
}
