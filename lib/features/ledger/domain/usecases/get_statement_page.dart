import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';

/// Resolves the user's filters into a repository query and loads a page.
final class GetStatementPage {
  const new({
    required this._repository,
    required this._clock,
    required this._calendar,
  });

  final TransactionRepository _repository;
  final Clock _clock;
  final LocalCalendar _calendar;

  Future<Result<TransactionPage>> call(
    StatementFilter filter, {
    PageCursor? cursor,
    int pageSize = TransactionPage.defaultSize,
  }) =>
      _repository.getPage(toQuery(filter), cursor: cursor, pageSize: pageSize);

  /// Presets are resolved against the clock now, so "last 7 days" always
  /// means the 7 days up to today (RN-14). Exposed for tests.
  TransactionQuery toQuery(StatementFilter filter) => TransactionQuery(
    direction: filter.direction,
    statuses: filter.statuses,
    range: filter.period.toRange(clock: _clock, calendar: _calendar),
    searchTerm: SearchText.toTerm(filter.search),
  );
}
