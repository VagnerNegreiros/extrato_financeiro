import 'dart:async';
import 'dart:math';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/ledger_calculator.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kept alive for the whole session, so filters, loaded pages and scroll
/// position survive opening a transaction and coming back (RN-23).
final statementViewModelProvider =
    NotifierProvider<StatementViewModel, StatementState>(
      StatementViewModel.new,
    );

class StatementViewModel extends Notifier<StatementState> {
  static const searchDebounce = Duration(milliseconds: 400);

  Timer? _debounce;

  /// Latest-wins guard for every request: a response that belongs to a
  /// superseded filter is discarded instead of overwriting newer results.
  int _version = 0;

  /// Search term of the page on screen, to skip reloads that would not
  /// change the result (e.g. typing a trailing space).
  String? _loadedTerm;

  /// Scroll offset restored when the view is rebuilt. Not part of the state
  /// because it changes on every frame and nothing renders from it.
  double savedScrollOffset = 0;

  @override
  StatementState build() {
    ref
      ..listen<AsyncValue<SyncInfo>>(syncInfoProvider, (_, next) {
        final info = next.value;
        if (info == null) return;
        final previous = state.syncInfo;
        state = state.copyWith(syncInfo: info);
        // Also when the first page is still loading: that read may predate
        // the sync, and the newer request supersedes it.
        if (info.lastSuccessAt != previous.lastSuccessAt) {
          unawaited(_reloadKeepingPages());
        }
      })
      ..onDispose(() => _debounce?.cancel());
    unawaited(Future.microtask(_initialize));
    return const StatementState();
  }

  Future<void> _initialize() async {
    // The listener only sees changes; a sync that finished (or failed)
    // before this screen opened must be picked up here.
    final current = ref.read(syncInfoProvider).value;
    if (current != null) state = state.copyWith(syncInfo: current);
    await _loadFirstPage(resetScroll: false);
  }

  /// Search with debounce (RN-17): the text updates at once, the query only
  /// after the user pauses typing.
  void updateSearch(String text) {
    if (text == state.filter.search) return;
    state = state.copyWith(filter: state.filter.copyWith(search: text));
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (SearchText.toTerm(state.filter.search) == _loadedTerm) return;
      unawaited(_loadFirstPage());
    });
  }

  Future<void> setDirection(TransactionDirection? direction) =>
      applyFilter(state.filter.copyWith(direction: direction));

  Future<void> toggleStatus(TransactionStatus status) {
    final statuses = {...state.filter.statuses};
    if (!statuses.remove(status)) statuses.add(status);
    return applyFilter(state.filter.copyWith(statuses: statuses));
  }

  Future<void> setPeriod(PeriodSelection period) =>
      applyFilter(state.filter.copyWith(period: period));

  /// Clears criteria and search ("Limpar filtros").
  Future<void> clearFilters() => applyFilter(StatementFilter.initial);

  /// Applies a whole filter at once (used by the filter sheet).
  Future<void> applyFilter(StatementFilter filter) async {
    _debounce?.cancel();
    if (filter == state.filter && state.status != StatementStatus.error) {
      return;
    }
    state = state.copyWith(filter: filter);
    await _loadFirstPage();
  }

  /// Infinite scroll. Ignored while a page is loading, when there is
  /// nothing more, or when the first page is not ready.
  Future<void> loadMore() async {
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.status != StatementStatus.ready) {
      return;
    }
    final version = _version;
    state = state.copyWith(isLoadingMore: true, loadMoreFailure: null);
    final result = await ref.read(getStatementPageProvider)(
      state.filter,
      cursor: state.nextCursor,
    );
    if (!ref.mounted || version != _version) return;

    state = switch (result) {
      Success(value: final page) => _withItems([
        ...state.items,
        ...page.items,
      ], page.nextCursor).copyWith(isLoadingMore: false),
      Err(:final failure) => state.copyWith(
        isLoadingMore: false,
        loadMoreFailure: failure,
      ),
    };
  }

  Future<Result<SyncInfo>> refresh() =>
      ref.read(syncCoordinatorProvider).refresh();

  Future<void> retry() async {
    if (state.status == StatementStatus.error) await _loadFirstPage();
    if (!state.syncInfo.hasData) await refresh();
  }

  Future<void> _loadFirstPage({
    bool resetScroll = true,
    int pageSize = TransactionPage.defaultSize,
    bool showLoading = true,
  }) async {
    final version = ++_version;
    final filter = state.filter;
    if (showLoading) {
      state = state.copyWith(
        status: StatementStatus.loading,
        isLoadingMore: false,
        loadMoreFailure: null,
      );
    }
    final result = await ref.read(getStatementPageProvider)(
      filter,
      pageSize: pageSize,
    );
    if (!ref.mounted || version != _version) return;

    switch (result) {
      case Success(value: final page):
        _loadedTerm = SearchText.toTerm(filter.search);
        state = _withItems(page.items, page.nextCursor).copyWith(
          status: StatementStatus.ready,
          failure: null,
          loadMoreFailure: null,
          resetToken: resetScroll ? state.resetToken + 1 : state.resetToken,
        );
      case Err(:final failure):
        // A failed background reload keeps what is already on screen.
        state = showLoading || state.items.isEmpty
            ? state.copyWith(status: StatementStatus.error, failure: failure)
            : state.copyWith(failure: failure);
    }
  }

  /// After a sync, reloads as many rows as are on screen so the list
  /// refreshes in place without losing the scroll position.
  Future<void> _reloadKeepingPages() => _loadFirstPage(
    resetScroll: false,
    showLoading: false,
    pageSize: max(state.items.length, TransactionPage.defaultSize),
  );

  StatementState _withItems(List<Transaction> items, PageCursor? cursor) {
    // Defensive de-duplication by id; keyset pagination should not repeat
    // rows, but a sync between pages must never show a row twice.
    final seen = <String>{};
    final unique = List<Transaction>.unmodifiable(
      items.where((item) => seen.add(item.id)),
    );
    return state.copyWith(
      items: unique,
      groups: LedgerCalculator.groupByDay(
        unique,
        calendar: ref.read(localCalendarProvider),
      ),
      nextCursor: cursor,
    );
  }
}
