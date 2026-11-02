import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';
import 'package:flutter/material.dart';

/// Search box. The text lives in the ViewModel (so it survives navigation);
/// this widget only mirrors it and reports changes.
class StatementSearchField extends StatefulWidget {
  const new({required this.text, required this.onChanged, super.key});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<StatementSearchField> createState() => _StatementSearchFieldState();
}

class _StatementSearchFieldState extends State<StatementSearchField> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(StatementSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External changes (e.g. "Limpar filtros") update the box.
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        maxLength: SearchText.maxLength,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por descrição',
          prefixIcon: const Icon(Icons.search_rounded),
          counterText: '',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          suffixIcon: ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
