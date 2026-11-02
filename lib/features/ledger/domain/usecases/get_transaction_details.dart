import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';

final class GetTransactionDetails {
  const new(this._repository);

  final TransactionRepository _repository;

  /// Reads the transaction from the cache, the same source as the
  /// statement, so both screens always show the same values (RN-32).
  Future<Result<Transaction>> call(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return const Err(NotFoundFailure('blank id'));
    return await _repository.getById(trimmed);
  }
}
