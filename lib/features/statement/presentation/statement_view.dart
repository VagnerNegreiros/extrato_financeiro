import 'dart:async';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_state.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view_model.dart';
import 'package:extrato_financeiro/features/statement/presentation/widgets/statement_filters.dart';
import 'package:extrato_financeiro/features/statement/presentation/widgets/statement_search_field.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:extrato_financeiro/shared/refresh_feedback.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:extrato_financeiro/shared/widgets/state_views.dart';
import 'package:extrato_financeiro/shared/widgets/sync_status_banner.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatementView extends ConsumerStatefulWidget {
  const new({super.key});

  /// Remaining scroll extent that triggers the next page.
  static const loadMoreThreshold = 600.0;

  @override
  ConsumerState<StatementView> createState() => _StatementViewState();
}

class _StatementViewState extends ConsumerState<StatementView> {
  late final StatementViewModel _viewModel = ref.read(
    statementViewModelProvider.notifier,
  );
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _viewModel.savedScrollOffset,
  )..addListener(_onScroll);

  void _onScroll() {
    _viewModel.savedScrollOffset = _scroll.offset;
    final position = _scroll.position;
    if (position.extentAfter < StatementView.loadMoreThreshold) {
      unawaited(_viewModel.loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openFilters(StatementState state) async {
    final filter = await showStatementFilterSheet(context, state.filter);
    if (filter != null) await _viewModel.applyFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statementViewModelProvider);
    ref.listen(statementViewModelProvider.select((s) => s.resetToken), (_, _) {
      _viewModel.savedScrollOffset = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });

    final filterCount = state.filter.activeCount;
    final activeLabel = filterCount == 1 ? 'ativo' : 'ativos';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato'),
        leading: BackButton(onPressed: context.back),
        actions: [
          IconButton(
            tooltip: filterCount == 0
                ? 'Filtros'
                : 'Filtros, $filterCount $activeLabel',
            onPressed: () => _openFilters(state),
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          StatementSearchField(
            text: state.filter.search,
            onChanged: _viewModel.updateSearch,
          ),
          ActiveFiltersBar(
            filter: state.filter,
            onClearDirection: () => _viewModel.setDirection(null),
            onRemoveStatus: _viewModel.toggleStatus,
            onResetPeriod: () =>
                _viewModel.setPeriod(PeriodSelection.defaultPeriod),
          ),
          const SyncStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshWithFeedback(context, _viewModel.refresh),
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _slivers(state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _slivers(StatementState state) {
    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child));

    switch (state.content) {
      case StatementContent.loading:
        return const [SliverToBoxAdapter(child: LoadingView(itemCount: 8))];
      case StatementContent.error:
        return [
          fill(
            ErrorView(
              failure: state.displayedFailure,
              onRetry: _viewModel.retry,
            ),
          ),
        ];
      case StatementContent.offline:
        return [
          fill(
            ErrorView(
              failure: const NetworkFailure(),
              onRetry: _viewModel.retry,
            ),
          ),
        ];
      case StatementContent.empty:
        return [
          fill(
            const EmptyView(
              title: 'Nenhuma transação',
              message: 'Suas movimentações aparecerão aqui.',
            ),
          ),
        ];
      case StatementContent.emptyFiltered:
        return [
          fill(
            EmptyView(
              icon: Icons.filter_alt_off_rounded,
              title: 'Nenhuma transação encontrada',
              message: 'Tente ajustar a busca ou os filtros.',
              actionLabel: 'Limpar filtros',
              onAction: _viewModel.clearFilters,
            ),
          ),
        ];
      case StatementContent.ready:
        return [
          for (final group in state.groups)
            SliverMainAxisGroup(
              key: ValueKey(group.date),
              slivers: [
                PinnedHeaderSliver(child: _DayHeader(group: group)),
                SliverList.builder(
                  itemCount: group.transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = group.transactions[index];
                    return TransactionTile(
                      transaction,
                      key: ValueKey(transaction.id),
                      onTap: () => context.openTransaction(transaction.id),
                    );
                  },
                ),
              ],
            ),
          SliverToBoxAdapter(
            child: _Footer(state: state, onRetry: _viewModel.loadMore),
          ),
        ];
    }
  }
}

class _DayHeader extends ConsumerWidget {
  const new({required this.group});

  final StatementGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = ref.watch(dateFormatterProvider).dayHeader(group.date);
    return Semantics(
      header: true,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              ExcludeSemantics(
                child: AmountText(
                  group.totals.net,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const new({required this.state, required this.onRetry});

  final StatementState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (state.isLoadingMore) {
      child = Semantics(
        label: 'Carregando mais transações',
        child: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (state.loadMoreFailure case final failure?) {
      child = Column(
        children: [
          Text(
            describeFailure(failure).title,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      );
    } else if (!state.hasMore) {
      child = Text(
        'Fim do extrato',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(child: child),
    );
  }
}
