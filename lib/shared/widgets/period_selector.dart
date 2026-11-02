import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/date_range_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _Option { last7, last30, last90, custom }

/// Presets (7/30/90 days) plus a custom range (RN-14/18), used by the
/// dashboard and the statement filters.
class PeriodSelector extends ConsumerWidget {
  const new({required this.selected, required this.onChanged, super.key});

  final PeriodSelection selected;
  final ValueChanged<PeriodSelection> onChanged;

  static const Map<_Option, PresetPeriod> _presets = {
    _Option.last7: PeriodSelection.last7Days,
    _Option.last30: PeriodSelection.last30Days,
    _Option.last90: PeriodSelection.last90Days,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = switch (selected) {
      CustomPeriod() => _Option.custom,
      final PresetPeriod preset =>
        _presets.entries
            .firstWhere(
              (entry) => entry.value == preset,
              orElse: () =>
                  const MapEntry(_Option.last30, PeriodSelection.last30Days),
            )
            .key,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Option>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Option.last7, label: Text('7 dias')),
            ButtonSegment(value: _Option.last30, label: Text('30 dias')),
            ButtonSegment(value: _Option.last90, label: Text('90 dias')),
            ButtonSegment(
              value: _Option.custom,
              icon: Icon(Icons.date_range_rounded),
              tooltip: 'Período personalizado',
            ),
          ],
          selected: {current},
          onSelectionChanged: (selection) async {
            final option = selection.single;
            if (option == _Option.custom) {
              final custom = await _pickCustom(context, ref);
              if (custom != null) onChanged(custom);
            } else {
              onChanged(_presets[option]!);
            }
          },
        ),
        if (selected case CustomPeriod(:final first, :final last))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_short(first)} a ${_short(last)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
      ],
    );
  }

  Future<PeriodSelection?> _pickCustom(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final today = ref
        .read(localCalendarProvider)
        .dateOf(ref.read(clockProvider).nowUtc());
    final initial = switch (selected) {
      CustomPeriod(:final first, :final last) => (first, last),
      _ => (today.addDays(-29), today),
    };
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _toDate(today.addDays(-(DateRangeValidator.maxDays - 1))),
      lastDate: _toDate(today),
      initialDateRange: DateTimeRange(
        start: _toDate(initial.$1),
        end: _toDate(initial.$2),
      ),
      helpText: 'Selecione o período',
      saveText: 'Aplicar',
    );
    if (picked == null) return null;

    final first = CalendarDate(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    );
    final last = CalendarDate(
      picked.end.year,
      picked.end.month,
      picked.end.day,
    );
    final error = DateRangeValidator.validate(
      first: first,
      last: last,
      today: today,
    );
    if (error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dateRangeErrorMessage(error))));
      }
      return null;
    }
    return CustomPeriod(first, last);
  }

  static DateTime _toDate(CalendarDate date) =>
      DateTime(date.year, date.month, date.day);

  static String _short(CalendarDate date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// RN-18 messages in pt-BR.
String dateRangeErrorMessage(DateRangeError error) => switch (error) {
  DateRangeError.startAfterEnd => 'A data inicial deve ser anterior à final.',
  DateRangeError.endInFuture => 'O período não pode terminar no futuro.',
  DateRangeError.tooLong =>
    'Escolha um período de até ${DateRangeValidator.maxDays} dias.',
  DateRangeError.beforeAvailableData =>
    'Não há dados disponíveis antes da data escolhida.',
};
