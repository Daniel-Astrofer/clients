import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';

class GetDepositAddressUseCase {
  final TransactionRepository repository;

  GetDepositAddressUseCase(this.repository);

  Future<Either<Failure, String>> call() async {
    return await repository.getDepositAddress();
  }
}
