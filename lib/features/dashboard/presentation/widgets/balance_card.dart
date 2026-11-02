import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:flutter/material.dart';

/// Available balance with the hide/show toggle (RN-06/08/29).
class BalanceCard extends StatelessWidget {
  const new({
    required this.balance,
    required this.isVisible,
    required this.onToggleVisibility,
    super.key,
  });

  final BalanceBreakdown balance;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reserved = balance.pendingDebits;

    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saldo disponível',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleVisibility,
                  tooltip: isVisible ? 'Ocultar saldo' : 'Exibir saldo',
                  color: colors.onPrimaryContainer,
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: FittedBox(
                key: ValueKey(isVisible),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AmountText(
                  balance.available,
                  obscured: !isVisible,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (reserved.isPositive) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                isVisible
                    ? '${const MoneyFormatter().format(reserved)} reservados '
                          'por saídas pendentes'
                    : 'Há saídas pendentes reservando parte do saldo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
