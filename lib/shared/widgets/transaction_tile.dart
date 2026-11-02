import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:extrato_financeiro/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One transaction in a list (dashboard and statement).
///
/// Screen readers get a single sentence for the whole row instead of
/// fragments: "Saída, Compra de Bitcoin, 43 reais e 47 centavos,
/// Concluída, 30 de outubro, 14:32".
class TransactionTile extends ConsumerWidget {
  const new(this.transaction, {this.onTap, this.showDate = false, super.key});

  final Transaction transaction;
  final VoidCallback? onTap;

  /// Shows the date next to the time (for lists not grouped by day).
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(dateFormatterProvider);
    final theme = Theme.of(context);
    final direction = transaction.direction;
    final time = dates.time(transaction.occurredAt);
    final when = showDate
        ? '${dates.shortDate(transaction.occurredAt)} · $time'
        : time;
    final noEffect =
        transaction.status == TransactionStatus.failed ||
        transaction.status == TransactionStatus.reversed;

    final semanticsLabel = [
      direction.label,
      transaction.description,
      AmountText.semanticLabel(transaction.amount),
      transaction.status.label,
      if (showDate) dates.shortDate(transaction.occurredAt),
      time,
    ].join(', ');

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: direction
                    .color(context)
                    .withValues(alpha: 0.12),
                child: Icon(
                  direction.icon,
                  color: direction.color(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$when · ${transaction.category.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AmountText(
                        transaction.amount,
                        direction: direction,
                        strikethrough: noEffect,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    StatusChip(transaction.status, dense: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
