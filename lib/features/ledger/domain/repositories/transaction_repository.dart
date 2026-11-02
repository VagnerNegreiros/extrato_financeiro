import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';

/// Access to the ledger. Reads always come from the local cache, which is
/// the single source of truth (RN-24); only [sync] talks to the network.
abstract interface class TransactionRepository {
  /// One page of transactions matching [query], newest first (RN-19/21).
  Future<Result<TransactionPage>> getPage(
    TransactionQuery query, {
    PageCursor? cursor,
    int pageSize = TransactionPage.defaultSize,
  });

  /// `NotFoundFailure` when [id] is unknown (RN-32).
  Future<Result<Transaction>> getById(String id);

  /// Every cached transaction: one consistent snapshot for the dashboard.
  Future<Result<List<Transaction>>> getAll();

  /// Refreshes the cache from the API.
  ///
  /// Without [force], it is a no-op while the cache is fresher than
  /// `SyncInfo.ttl` (RN-26). Concurrent calls share the same request.
  Future<Result<SyncInfo>> sync({bool force = false});

  /// Current sync state, then every change (cache updated, failure...).
  Stream<SyncInfo> watchSyncInfo();
}
