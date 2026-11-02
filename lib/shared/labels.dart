import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:flutter/material.dart';

/// pt-BR labels and icons for domain enums, shared by every screen so the
/// statement and the details always describe a transaction the same way.
extension TransactionDirectionLabel on TransactionDirection {
  String get label => switch (this) {
    TransactionDirection.credit => 'Entrada',
    TransactionDirection.debit => 'Saída',
  };

  /// Arrow into the account for credits, out of it for debits.
  IconData get icon => switch (this) {
    TransactionDirection.credit => Icons.south_west_rounded,
    TransactionDirection.debit => Icons.north_east_rounded,
  };

  Color color(BuildContext context) => switch (this) {
    TransactionDirection.credit => context.financialColors.credit,
    TransactionDirection.debit => context.financialColors.debit,
  };
}

extension TransactionStatusLabel on TransactionStatus {
  String get label => switch (this) {
    TransactionStatus.completed => 'Concluída',
    TransactionStatus.pending => 'Pendente',
    TransactionStatus.failed => 'Falha',
    TransactionStatus.reversed => 'Estornada',
  };

  IconData get icon => switch (this) {
    TransactionStatus.completed => Icons.check_circle_outline_rounded,
    TransactionStatus.pending => Icons.schedule_rounded,
    TransactionStatus.failed => Icons.cancel_outlined,
    TransactionStatus.reversed => Icons.undo_rounded,
  };

  Color color(BuildContext context) {
    final colors = context.financialColors;
    return switch (this) {
      TransactionStatus.completed => colors.completed,
      TransactionStatus.pending => colors.pending,
      TransactionStatus.failed => colors.failed,
      TransactionStatus.reversed => colors.reversed,
    };
  }
}

extension TransactionCategoryLabel on TransactionCategory {
  String get label => switch (this) {
    TransactionCategory.opening => 'Saldo inicial',
    TransactionCategory.deposit => 'Depósito',
    TransactionCategory.withdrawal => 'Saque',
    TransactionCategory.cryptoBuy => 'Compra de cripto',
    TransactionCategory.cryptoSell => 'Venda de cripto',
    TransactionCategory.fee => 'Tarifa',
  };
}

/// pt-BR decimal formatting for asset quantities: `0,00012345`.
String formatDecimal(Decimal value) => value.toString().replaceAll('.', ',');

/// `+1,25%` / `−0,40%`, rounded to two decimal places.
String formatPercent(Decimal value) {
  final rounded = value.round(scale: 2);
  final sign = rounded.isNegative() ? '−' : '+';
  return '$sign${rounded.abs().toStringAsFixed(2).replaceAll('.', ',')}%';
}

extension on Decimal {
  bool isNegative() => this < Decimal.zero;
}
