import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Label/value pair used by the details screen.
class InfoRow extends StatelessWidget {
  const new({
    required this.label,
    this.value,
    this.child,
    this.trailing,
    super.key,
  }) : assert(value != null || child != null, 'value or child is required');

  final String label;
  final String? value;

  /// Custom value widget (e.g. an `AmountText`), used instead of [value].
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  child ??
                      SelectableText(value!, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
