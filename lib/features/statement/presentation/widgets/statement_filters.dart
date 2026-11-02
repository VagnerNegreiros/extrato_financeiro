import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:extrato_financeiro/shared/widgets/period_selector.dart';
import 'package:flutter/material.dart';

enum _DirectionOption { all, credit, debit }

/// Bottom sheet that edits a draft filter and applies it at once, so the
/// list reloads a single time instead of on every tap (RN-16).
Future<StatementFilter?> showStatementFilterSheet(
  BuildContext context,
  StatementFilter current,
) => showModalBottomSheet<StatementFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _FilterSheet(initial: current),
);

class _FilterSheet extends StatefulWidget {
  const new({required this.initial});

  final StatementFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late StatementFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final direction = switch (_draft.direction) {
      null => _DirectionOption.all,
      TransactionDirection.credit => _DirectionOption.credit,
      TransactionDirection.debit => _DirectionOption.debit,
    };

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleSmall),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filtros', style: textTheme.titleLarge),
          title('Tipo'),
          SegmentedButton<_DirectionOption>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: _DirectionOption.all,
                label: Text('Todas'),
              ),
              ButtonSegment(
                value: _DirectionOption.credit,
                icon: Icon(TransactionDirection.credit.icon),
                label: const Text('Entradas'),
              ),
              ButtonSegment(
                value: _DirectionOption.debit,
                icon: Icon(TransactionDirection.debit.icon),
                label: const Text('Saídas'),
              ),
            ],
            selected: {direction},
            onSelectionChanged: (selection) => setState(
              () => _draft = _draft.copyWith(
                direction: switch (selection.single) {
                  _DirectionOption.all => null,
                  _DirectionOption.credit => TransactionDirection.credit,
                  _DirectionOption.debit => TransactionDirection.debit,
                },
              ),
            ),
          ),
          title('Status'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in TransactionStatus.values)
                FilterChip(
                  avatar: Icon(status.icon, size: 18),
                  label: Text(status.label),
                  selected: _draft.statuses.contains(status),
                  onSelected: (selected) => setState(() {
                    final statuses = {..._draft.statuses};
                    selected ? statuses.add(status) : statuses.remove(status);
                    _draft = _draft.copyWith(statuses: statuses);
                  }),
                ),
            ],
          ),
          title('Período'),
          PeriodSelector(
            selected: _draft.period,
            onChanged: (period) =>
                setState(() => _draft = _draft.copyWith(period: period)),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _draft = StatementFilter(search: _draft.search),
                  ),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Removable chips summarizing the active criteria.
class ActiveFiltersBar extends StatelessWidget {
  const new({
    required this.filter,
    required this.onClearDirection,
    required this.onRemoveStatus,
    required this.onResetPeriod,
    super.key,
  });

  final StatementFilter filter;
  final VoidCallback onClearDirection;
  final ValueChanged<TransactionStatus> onRemoveStatus;
  final VoidCallback onResetPeriod;

  @override
  Widget build(BuildContext context) {
    final direction = filter.direction;
    final period = filter.period;
    final chips = [
      if (direction != null)
        InputChip(
          avatar: Icon(direction.icon, size: 18),
          label: Text(
            direction == TransactionDirection.credit ? 'Entradas' : 'Saídas',
          ),
          onDeleted: onClearDirection,
          deleteButtonTooltipMessage: 'Remover filtro de tipo',
        ),
      for (final status in filter.statuses)
        InputChip(
          avatar: Icon(status.icon, size: 18),
          label: Text(status.label),
          onDeleted: () => onRemoveStatus(status),
          deleteButtonTooltipMessage: 'Remover filtro ${status.label}',
        ),
      if (period != PeriodSelection.defaultPeriod)
        InputChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(periodLabel(period)),
          onDeleted: onResetPeriod,
          deleteButtonTooltipMessage: 'Voltar para 30 dias',
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: chip,
            ),
        ],
      ),
    );
  }
}

String periodLabel(PeriodSelection period) => switch (period) {
  PresetPeriod(:final days) => 'Últimos $days dias',
  CustomPeriod(:final first, :final last) =>
    '${_short(first.day, first.month)} a ${_short(last.day, last.month)}',
};

String _short(int day, int month) =>
    '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}';
