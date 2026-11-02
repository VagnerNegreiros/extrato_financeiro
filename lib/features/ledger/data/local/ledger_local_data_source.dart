import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/ledger/data/local/app_database.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';

/// Position after which the next page starts (keyset pagination, RN-21).
typedef StatementPosition = ({DateTime occurredAt, String id});

/// What the cache knows about the last successful sync.
typedef LedgerSyncMetadata = ({DateTime? lastSuccessAt, CalendarDate? anchor});

/// Drift-backed ledger cache. Every failure surfaces as [CacheException].
final class LedgerLocalDataSource {
  new(this._db);

  static const _resource = 'ledger';

  final AppDatabase _db;

  /// Transactions matching [query] after [after], newest first (RN-19).
  ///
  /// Filters mirror `TransactionQuery.matches`; the keyset condition uses
  /// `(occurred_at, id)` so pages stay stable while new rows are inserted.
  Future<List<Transaction>> queryPage(
    TransactionQuery query, {
    required int limit,
    StatementPosition? after,
  }) => _guard(() async {
    final t = _db.transactionRows;
    final select = _db.select(t)
      ..where((row) => _matches(row, query, after))
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.id),
      ])
      ..limit(limit);
    final rows = await select.get();
    return rows.map(_toEntity).toList();
  });

  Future<Transaction?> findById(String id) => _guard(() async {
    final row = await (_db.select(
      _db.transactionRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  });

  Future<List<Transaction>> findAll() => _guard(() async {
    final rows = await _db.select(_db.transactionRows).get();
    return rows.map(_toEntity).toList();
  });

  /// Replaces the ledger and the sync metadata atomically: readers see
  /// either the old snapshot or the new one, never a mix.
  Future<void> replaceAll(
    List<Transaction> transactions, {
    required DateTime syncedAt,
    required CalendarDate anchor,
  }) => _guard(() async {
    final updatedAt = syncedAt.millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db.delete(_db.transactionRows).go();
      await _db.batch((batch) {
        batch.insertAll(_db.transactionRows, [
          for (final transaction in transactions)
            _toCompanion(transaction, updatedAt),
        ]);
      });
      await _db
          .into(_db.syncMetadataRows)
          .insertOnConflictUpdate(
            SyncMetadataRowsCompanion.insert(
              resource: _resource,
              lastSuccessAt: Value(updatedAt),
              anchorDay: Value(anchor.toString()),
            ),
          );
    });
  });

  Future<LedgerSyncMetadata> readMetadata() => _guard(() async {
    final row = await (_db.select(
      _db.syncMetadataRows,
    )..where((t) => t.resource.equals(_resource))).getSingleOrNull();
    final lastSuccess = row?.lastSuccessAt;
    return (
      lastSuccessAt: lastSuccess == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSuccess, isUtc: true),
      anchor: _parseDay(row?.anchorDay),
    );
  });

  Expression<bool> _matches(
    $TransactionRowsTable row,
    TransactionQuery query,
    StatementPosition? after,
  ) {
    final conditions = <Expression<bool>>[
      if (query.direction case final direction?)
        row.direction.equalsValue(direction),
      if (query.statuses.isNotEmpty)
        row.status.isIn(query.statuses.map((s) => s.name)),
      if (query.range case final range?) ...[
        row.occurredAt.isBiggerOrEqualValue(
          range.startUtc.millisecondsSinceEpoch,
        ),
        row.occurredAt.isSmallerThanValue(range.endUtc.millisecondsSinceEpoch),
      ],
      if (query.searchTerm case final term?)
        row.descriptionSearch.like('%${_escapeLike(term)}%', escapeChar: r'\'),
      if (after != null)
        row.occurredAt.isSmallerThanValue(
              after.occurredAt.millisecondsSinceEpoch,
            ) |
            (row.occurredAt.equals(after.occurredAt.millisecondsSinceEpoch) &
                row.id.isSmallerThanValue(after.id)),
    ];
    return conditions.isEmpty
        ? const Constant(true)
        : Expression.and(conditions);
  }

  /// `%` and `_` typed by the user are literal characters, not wildcards.
  static String _escapeLike(String term) => term
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static CalendarDate? _parseDay(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    return parsed == null
        ? null
        : CalendarDate(parsed.year, parsed.month, parsed.day);
  }

  static TransactionRowsCompanion _toCompanion(
    Transaction transaction,
    int updatedAt,
  ) {
    final metadata = transaction.metadata;
    return TransactionRowsCompanion.insert(
      id: transaction.id,
      description: transaction.description,
      descriptionSearch: SearchText.normalize(transaction.description),
      amountCents: transaction.amount.cents,
      direction: transaction.direction,
      status: transaction.status,
      category: transaction.category,
      occurredAt: transaction.occurredAt.millisecondsSinceEpoch,
      assetId: Value(metadata.assetId),
      assetSymbol: Value(metadata.assetSymbol),
      assetQuantity: Value(metadata.assetQuantity?.toString()),
      unitPriceCents: Value(metadata.unitPrice?.cents),
      counterparty: Value(metadata.counterparty),
      updatedAt: updatedAt,
    );
  }

  static Transaction _toEntity(TransactionRow row) => Transaction(
    id: row.id,
    description: row.description,
    amount: Money(row.amountCents),
    direction: row.direction,
    status: row.status,
    category: row.category,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      row.occurredAt,
      isUtc: true,
    ),
    metadata: TransactionMetadata(
      assetId: row.assetId,
      assetSymbol: row.assetSymbol,
      assetQuantity: row.assetQuantity == null
          ? null
          : Decimal.tryParse(row.assetQuantity!),
      unitPrice: row.unitPriceCents == null ? null : Money(row.unitPriceCents!),
      counterparty: row.counterparty,
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CacheException {
      rethrow;
    } on Object catch (error) {
      // Includes invalid rows rejected by the entity invariants.
      throw CacheException(error.toString());
    }
  }
}
