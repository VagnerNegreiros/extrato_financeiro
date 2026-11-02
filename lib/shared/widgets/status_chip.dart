import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:flutter/material.dart';

/// Status as icon + text (never color alone).
class StatusChip extends StatelessWidget {
  const new(this.status, {this.dense = false, super.key});

  final TransactionStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    final textStyle =
        (dense
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(color: color, fontWeight: FontWeight.w600);

    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.xs + 2 : AppSpacing.sm,
          vertical: dense ? 1 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: dense ? 12 : 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                status.label,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
