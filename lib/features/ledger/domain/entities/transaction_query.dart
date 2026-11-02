import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_query.freezed.dart';

/// Repository-level filter, already resolved and validated (RN-16).
///
/// Every criterion is combined with AND; `null` or empty means "any".
@freezed
abstract class TransactionQuery with _$TransactionQuery {
  const factory({
    TransactionDirection? direction,
    @Default(<TransactionStatus>{}) Set<TransactionStatus> statuses,
    DateRange? range,

    /// Normalized term (see [SearchText.toTerm]); `null` disables search.
    String? searchTerm,
  }) = _TransactionQuery;

  const new _();

  static const all = TransactionQuery();

  /// In-memory definition of the filter. The SQL implementation must agree
  /// with it, which lets the rule be unit tested without a database.
  bool matches(Transaction transaction) {
    if (direction != null && transaction.direction != direction) return false;
    if (statuses.isNotEmpty && !statuses.contains(transaction.status)) {
      return false;
    }
    final range = this.range;
    if (range != null && !range.contains(transaction.occurredAt)) return false;
    final term = searchTerm;
    if (term != null &&
        !SearchText.normalize(transaction.description).contains(term)) {
      return false;
    }
    return true;
  }
}

/// Opaque position in the statement used for keyset pagination (RN-21).
///
/// Only the data layer knows how to encode and decode [value].
@immutable
final class PageCursor {
  const new(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is PageCursor && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// One page of the statement, newest first (RN-19).
@freezed
abstract class TransactionPage with _$TransactionPage {
  const factory({
    required List<Transaction> items,

    /// Cursor for the next page; `null` when this is the last one.
    PageCursor? nextCursor,
  }) = _TransactionPage;

  const new _();

  /// Default page size (RN-21).
  static const defaultSize = 20;

  bool get hasMore => nextCursor != null;
}
