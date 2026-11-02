import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Income vs expenses per day (or week) of the selected period.
///
/// Bar heights are the only place where money becomes `double`: geometry
/// needs it, but every number shown as text is formatted from [Money].
class CashflowChart extends StatelessWidget {
  const new({required this.buckets, required this.obscured, super.key});

  final List<CashflowBucket> buckets;

  /// When the balance is hidden, tooltips with amounts are disabled.
  final bool obscured;

  static const _formatter = MoneyFormatter();

  @override
  Widget build(BuildContext context) {
    final colors = context.financialColors;
    final theme = Theme.of(context);
    final isWeekly =
        buckets.isNotEmpty && buckets.first.first != buckets.first.last;
    final labelEvery = (buckets.length / 6).ceil().clamp(1, 31);

    return Semantics(
      label: _semanticSummary(),
      excludeSemantics: true,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: !obscured,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItem: (group, _, rod, rodIndex) {
                  final totals = buckets[group.x].totals;
                  final value = rodIndex == 0 ? totals.income : totals.expenses;
                  return BarTooltipItem(
                    '${rodIndex == 0 ? 'Entradas' : 'Saídas'}\n'
                    '${_formatter.format(value)}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index % labelEvery != 0 || index >= buckets.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _label(buckets[index].first, weekly: isWeekly),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (final (index, bucket) in buckets.indexed)
                BarChartGroupData(
                  x: index,
                  barsSpace: 2,
                  barRods: [
                    _rod(bucket.totals.income, colors.credit),
                    _rod(bucket.totals.expenses, colors.debit),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartRodData _rod(Money value, Color color) => BarChartRodData(
    toY: value.cents / 100,
    color: color,
    width: buckets.length > 15 ? 3 : 6,
    borderRadius: BorderRadius.circular(2),
  );

  String _semanticSummary() {
    if (obscured) {
      return 'Gráfico de entradas e saídas do período, valores ocultos';
    }
    final income = Money.sum(buckets.map((b) => b.totals.income));
    final expenses = Money.sum(buckets.map((b) => b.totals.expenses));
    return 'Gráfico de entradas e saídas: entradas de '
        '${_formatter.spoken(income)}, '
        'saídas de ${_formatter.spoken(expenses)}';
  }

  static String _label(CalendarDate date, {required bool weekly}) {
    final day = date.day.toString().padLeft(2, '0');
    return weekly ? '$day/${date.month.toString().padLeft(2, '0')}' : day;
  }
}
