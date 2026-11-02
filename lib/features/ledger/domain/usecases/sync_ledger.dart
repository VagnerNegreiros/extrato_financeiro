import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';

/// Refreshes the local ledger and exposes the sync state to every screen.
final class SyncLedger {
  const new(this._repository);

  final TransactionRepository _repository;

  /// [force] is used by pull-to-refresh; automatic syncs respect the TTL
  /// (RN-26). Deduplication happens in the repository.
  Future<Result<SyncInfo>> call({bool force = false}) =>
      _repository.sync(force: force);

  Stream<SyncInfo> watch() => _repository.watchSyncInfo();
}
