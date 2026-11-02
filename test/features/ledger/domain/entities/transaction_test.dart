import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/transaction_builder.dart';

Transaction _build({
  String id = 'TX-1',
  String description = 'Compra de BTC',
  int cents = 1000,
  DateTime? occurredAt,
}) => Transaction(
  id: id,
  description: description,
  amount: Money(cents),
  direction: TransactionDirection.debit,
  status: TransactionStatus.completed,
  category: TransactionCategory.cryptoBuy,
  occurredAt: occurredAt ?? DateTime.utc(2026, 10, 30, 17, 32),
);

void main() {
  group('RN-02: amount is positive, sign comes from direction', () {
    test('rejects zero and negative amounts', () {
      expect(() => _build(cents: 0), throwsArgumentError);
      expect(() => _build(cents: -1), throwsArgumentError);
    });

    test('signedAmount follows the direction', () {
      expect(credit(500).signedAmount, const Money(500));
      expect(debit(500).signedAmount, const Money(-500));
    });
  });

  group('RN-10: occurredAt is UTC', () {
    test('rejects local DateTimes', () {
      expect(
        () => _build(occurredAt: DateTime(2026, 10, 30)),
        throwsArgumentError,
      );
    });
  });

  group('invariants', () {
    test('rejects blank id and description', () {
      expect(() => _build(id: '  '), throwsArgumentError);
      expect(() => _build(description: ''), throwsArgumentError);
    });

    test('trims the description', () {
      expect(
        _build(description: '  Compra de BTC ').description,
        'Compra de BTC',
      );
    });
  });

  group('RN-19: statement ordering', () {
    test('newest first, ties broken by id descending', () {
      final older = tx(cents: 1, id: 'TX-A', at: DateTime.utc(2026, 10));
      final newerA = tx(cents: 1, id: 'TX-A', at: DateTime.utc(2026, 10, 2));
      final newerB = tx(cents: 1, id: 'TX-B', at: DateTime.utc(2026, 10, 2));

      final sorted = [older, newerA, newerB]..sort(Transaction.newestFirst);

      expect(sorted, [newerB, newerA, older]);
    });
  });

  group('value semantics', () {
    test('equality covers every field, including metadata', () {
      final metadata = TransactionMetadata(
        assetId: 'bitcoin',
        assetSymbol: 'BTC',
        assetQuantity: Decimal.parse('0.00012345'),
        unitPrice: const Money(35212345),
        counterparty: 'Corretora Fluxo',
      );
      Transaction build() => Transaction(
        id: 'TX-1',
        description: 'Compra de BTC',
        amount: const Money(4347),
        direction: TransactionDirection.debit,
        status: TransactionStatus.completed,
        category: TransactionCategory.cryptoBuy,
        occurredAt: DateTime.utc(2026, 10, 30),
        metadata: metadata,
      );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(metadata.isEmpty, isFalse);
      expect(TransactionMetadata.empty.isEmpty, isTrue);
      expect(metadata.hashCode, isNot(TransactionMetadata.empty.hashCode));
    });

    test('copyWith changes only the status and keeps the id (RN-28)', () {
      final pending = tx(cents: 100, status: TransactionStatus.pending);
      final settled = pending.copyWith(status: TransactionStatus.completed);

      expect(settled.id, pending.id);
      expect(settled.status, TransactionStatus.completed);
      expect(settled.amount, pending.amount);
      expect(settled, isNot(pending));
      expect(pending.copyWith(), pending);
    });

    test('toString never exposes amount or description', () {
      final text = _build(cents: 987654).toString();
      expect(text, isNot(contains('9876')));
      expect(text, isNot(contains('BTC')));
      expect(text, contains('TX-1'));
    });
  });

  group('enums', () {
    test('only completed counts in totals', () {
      expect(TransactionStatus.values.where((s) => s.countsInTotals), [
        TransactionStatus.completed,
      ]);
      expect(TransactionDirection.credit.isCredit, isTrue);
      expect(TransactionDirection.debit.isCredit, isFalse);
    });
  });
}
