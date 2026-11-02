import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/dashboard_state.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/widgets/balance_card.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/widgets/period_summary_card.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/shared/refresh_feedback.dart';
import 'package:extrato_financeiro/shared/widgets/period_selector.dart';
import 'package:extrato_financeiro/shared/widgets/state_views.dart';
import 'package:extrato_financeiro/shared/widgets/sync_status_banner.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final viewModel = ref.read(dashboardViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Fluxo')),
      body: RefreshIndicator(
        onRefresh: () => refreshWithFeedback(context, viewModel.refresh),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SyncStatusBanner()),
            ..._content(context, state, viewModel),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    DashboardState state,
    DashboardViewModel viewModel,
  ) {
    switch (state.content) {
      case DashboardContent.loading:
        return const [SliverToBoxAdapter(child: LoadingView())];
      case DashboardContent.offline:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ErrorView(
                failure: const NetworkFailure(),
                onRetry: viewModel.retry,
              ),
            ),
          ),
        ];
      case DashboardContent.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ErrorView(
                failure: state.displayedFailure,
                onRetry: viewModel.retry,
              ),
            ),
          ),
        ];
      case DashboardContent.empty:
      case DashboardContent.ready:
        return _summarySlivers(context, state, state.summary!, viewModel);
    }
  }

  List<Widget> _summarySlivers(
    BuildContext context,
    DashboardState state,
    DashboardSummary summary,
    DashboardViewModel viewModel,
  ) {
    final obscured = !state.isBalanceVisible;
    final textTheme = Theme.of(context).textTheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        sliver: SliverList.list(
          children: [
            BalanceCard(
              balance: summary.balance,
              isVisible: state.isBalanceVisible,
              onToggleVisibility: viewModel.toggleBalanceVisibility,
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text(
                'Movimentação do período',
                style: textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PeriodSelector(
              selected: state.period,
              onChanged: viewModel.selectPeriod,
            ),
            const SizedBox(height: AppSpacing.md),
            PeriodSummaryCard(
              totals: summary.totals,
              cashflow: summary.cashflow,
              obscured: obscured,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Últimas transações',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: context.openStatement,
                  child: const Text('Ver extrato completo'),
                ),
              ],
            ),
          ],
        ),
      ),
      if (summary.recent.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyView(
            title: 'Nenhuma transação ainda',
            message: 'Suas movimentações aparecerão aqui.',
          ),
        )
      else
        SliverList.builder(
          itemCount: summary.recent.length,
          itemBuilder: (context, index) {
            final transaction = summary.recent[index];
            return TransactionTile(
              transaction,
              showDate: true,
              onTap: () => context.openTransaction(transaction.id),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
    ];
  }
}
