import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';

var _sequence = 0;

/// Concise transaction factory for tests. Amounts are in cents.
Transaction tx({
  required int cents,
  TransactionDirection direction = TransactionDirection.credit,
  TransactionStatus status = TransactionStatus.completed,
  TransactionCategory category = TransactionCategory.deposit,
  DateTime? at,
  String? id,
  String description = 'Depósito Pix',
  TransactionMetadata metadata = TransactionMetadata.empty,
}) => Transaction(
  id: id ?? 'TX-${(_sequence++).toString().padLeft(4, '0')}',
  description: description,
  amount: Money(cents),
  direction: direction,
  status: status,
  category: category,
  occurredAt: at ?? DateTime.utc(2026, 10, 15, 12),
  metadata: metadata,
);

Transaction credit(int cents, {DateTime? at, TransactionStatus? status}) =>
    tx(cents: cents, at: at, status: status ?? TransactionStatus.completed);

Transaction debit(int cents, {DateTime? at, TransactionStatus? status}) => tx(
  cents: cents,
  direction: TransactionDirection.debit,
  category: TransactionCategory.withdrawal,
  description: 'Saque Pix',
  at: at,
  status: status ?? TransactionStatus.completed,
);
