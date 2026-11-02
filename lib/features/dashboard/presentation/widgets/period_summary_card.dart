import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/widgets/cashflow_chart.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:flutter/material.dart';

/// Income, expenses and result of the period, plus the chart (RN-07).
class PeriodSummaryCard extends StatelessWidget {
  const new({
    required this.totals,
    required this.cashflow,
    required this.obscured,
    super.key,
  });

  final PeriodTotals totals;
  final List<CashflowBucket> cashflow;
  final bool obscured;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _Figure(
                  label: 'Entradas',
                  amount: totals.income,
                  direction: TransactionDirection.credit,
                  obscured: obscured,
                ),
                _Figure(
                  label: 'Saídas',
                  amount: totals.expenses,
                  direction: TransactionDirection.debit,
                  obscured: obscured,
                ),
                _Figure(
                  label: 'Resultado',
                  amount: totals.net,
                  obscured: obscured,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            CashflowChart(buckets: cashflow, obscured: obscured),
            const SizedBox(height: AppSpacing.sm),
            const _Legend(),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const new({
    required this.label,
    required this.amount,
    required this.obscured,
    this.direction,
  });

  final String label;
  final Money amount;
  final bool obscured;
  final TransactionDirection? direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (direction != null) ...[
                Icon(
                  direction!.icon,
                  size: 16,
                  color: direction!.color(context),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
          AmountText(
            amount,
            direction: direction,
            obscured: obscured,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = context.financialColors;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget item(Color color, IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: style),
      ],
    );

    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.lg,
        children: [
          item(
            colors.credit,
            TransactionDirection.credit.icon,
            'Entradas (barra à esquerda)',
          ),
          item(
            colors.debit,
            TransactionDirection.debit.icon,
            'Saídas (barra à direita)',
          ),
        ],
      ),
    );
  }
}
