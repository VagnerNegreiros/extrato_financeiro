import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statement_filter.freezed.dart';

/// Filters chosen by the user on the statement screen (RN-16).
///
/// Holds raw user input (the search text as typed); `GetStatementPage`
/// resolves it into a `TransactionQuery`.
@freezed
abstract class StatementFilter with _$StatementFilter {
  const factory({
    /// `null` means both directions.
    TransactionDirection? direction,

    /// Empty means every status.
    @Default(<TransactionStatus>{}) Set<TransactionStatus> statuses,
    @Default(PeriodSelection.defaultPeriod) PeriodSelection period,
    @Default('') String search,
  }) = _StatementFilter;

  const new _();

  static const initial = StatementFilter();

  /// Number of criteria that differ from the defaults, for the filter badge.
  /// The search box is visible on its own, so it is not counted.
  int get activeCount =>
      (direction == null ? 0 : 1) +
      (statuses.isEmpty ? 0 : 1) +
      (period == PeriodSelection.defaultPeriod ? 0 : 1);

  bool get hasActiveCriteria => activeCount > 0 || search.trim().isNotEmpty;

  /// Clears every criterion but keeps the search text.
  StatementFilter clearCriteria() => StatementFilter(search: search);
}
