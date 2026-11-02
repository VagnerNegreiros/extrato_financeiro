import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';
import 'package:extrato_financeiro/features/ledger/data/ledger/ledger_factory.dart';
import 'package:extrato_financeiro/features/ledger/data/ledger/seeded_random.dart';
import 'package:extrato_financeiro/features/ledger/data/tracked_asset.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/ledger_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_market.dart';

void main() {
  const factory = LedgerFactory();
  // Charts cover 120 days up to this instant; ledgers are built "in the past"
  // by passing an earlier `nowUtc`.
  final chartClock = FixedClock(DateTime.utc(2026, 11, 2, 18));
  late Map<TrackedAsset, MarketChartDto> charts;
  final anchor = utcDay(DateTime.utc(2026, 8, 5));

  setUpAll(() async => charts = await chartsFor(chartClock, days: 120));

  List<Transaction> build(DateTime now) =>
      factory.build(charts: charts, anchor: anchor, nowUtc: now);

  final now = DateTime.utc(2026, 11, 2, 15);

  test('is deterministic for the same input', () {
    expect(build(now), build(now));
  });

  test('ids are unique, stable and readable', () {
    final ledger = build(now);
    final ids = ledger.map((t) => t.id).toSet();
    expect(ids, hasLength(ledger.length));
    expect(
      ledger.every((t) => RegExp(r'^TX-\d{8}-\d{2}$').hasMatch(t.id)),
      isTrue,
    );
    expect(ledger.length, greaterThan(150));
  });

  test('starts with the opening balance on the anchor day', () {
    final ledger = build(now);
    final opening = ledger.last;
    expect(opening.category, TransactionCategory.opening);
    expect(opening.amount, LedgerFactory.openingBalance);
    expect(opening.status, TransactionStatus.completed);
    expect(utcDay(opening.occurredAt), anchor);
  });

  test('never includes entries after now, and is sorted newest first', () {
    final ledger = build(now);
    expect(ledger.every((t) => !t.occurredAt.isAfter(now)), isTrue);
    final sorted = [...ledger]..sort(Transaction.newestFirst);
    expect(ledger, sorted);
  });

  test('available balance is never negative at any point in time', () {
    for (var hours = 0; hours < 24 * 89; hours += 7) {
      final instant = DateTime.utc(2026, 8, 5, 6).add(Duration(hours: hours));
      final balance = LedgerCalculator.balance(build(instant));
      expect(balance.available.isNegative, isFalse, reason: '$instant');
    }
  });

  test('past entries are stable as days go by; only statuses evolve', () {
    final earlier = build(DateTime.utc(2026, 10, 20, 12));
    final later = {for (final t in build(now)) t.id: t};

    var settled = 0;
    for (final transaction in earlier) {
      final current = later[transaction.id];
      expect(current, isNotNull, reason: transaction.id);
      expect(current!.copyWith(status: transaction.status), transaction);
      if (transaction.status == TransactionStatus.pending &&
          current.status == TransactionStatus.completed) {
        settled++;
      }
      if (transaction.status == TransactionStatus.failed) {
        expect(current.status, TransactionStatus.failed);
      }
    }
    // RN-28: pending entries settle without changing their id.
    expect(settled, greaterThan(0));
  });

  test('a longer history does not change the overlapping days', () async {
    final longerCharts = await chartsFor(chartClock, days: 200);
    final fromLonger = factory.build(
      charts: longerCharts,
      anchor: anchor,
      nowUtc: now,
    );
    expect(fromLonger, build(now));
  });

  test('trades carry asset metadata and are followed by their fee', () {
    final byId = {for (final t in build(now)) t.id: t};
    final trades = byId.values.where(
      (t) =>
          t.category == TransactionCategory.cryptoBuy ||
          t.category == TransactionCategory.cryptoSell,
    );
    expect(trades, isNotEmpty);

    for (final trade in trades) {
      final metadata = trade.metadata;
      expect(metadata.assetId, isNotNull);
      expect(metadata.assetQuantity!.scale, lessThanOrEqualTo(8));
      expect(metadata.unitPrice!.isPositive, isTrue);
      expect(metadata.counterparty, LedgerFactory.counterparty);

      // amount ~= quantity * unit price (unit price is itself rounded).
      final approx = Money.fromDecimal(
        metadata.assetQuantity! * metadata.unitPrice!.toDecimal(),
      );
      expect((approx - trade.amount).abs().cents, lessThanOrEqualTo(1));

      final sequence = int.parse(trade.id.substring(trade.id.length - 2));
      final feeId =
          '${trade.id.substring(0, trade.id.length - 2)}'
          '${(sequence + 1).toString().padLeft(2, '0')}';
      final fee = byId[feeId];
      if (fee == null) continue; // fee scheduled after `now`
      expect(fee.category, TransactionCategory.fee);
      expect(fee.direction, TransactionDirection.debit);
      expect(fee.metadata.assetId, metadata.assetId);
      final expected = Money.fromDecimal(
        trade.amount.toDecimal() * Decimal.parse('0.005'),
      );
      expect(fee.amount, expected.isPositive ? expected : const Money(1));
    }
  });

  test('every category and status appears in a 90-day ledger', () {
    final ledger = build(now);
    expect(
      ledger.map((t) => t.category).toSet(),
      TransactionCategory.values.toSet(),
    );
    expect(
      ledger.map((t) => t.status).toSet(),
      TransactionStatus.values.toSet(),
    );
  });

  test('salary is deposited on the 5th of each month', () {
    final salaries = build(now).where((t) => t.description.contains('Salário'));
    expect(salaries.map((t) => t.occurredAt.month).toSet(), {8, 9, 10});
    expect(salaries.every((t) => t.occurredAt.day == 5), isTrue);
  });

  test('missing price days skip trades but keep deposits', () {
    final noCharts = factory.build(
      charts: const {},
      anchor: anchor,
      nowUtc: now,
    );
    expect(noCharts.where((t) => t.metadata.assetId != null), isEmpty);
    expect(noCharts.first.category, isNot(TransactionCategory.cryptoBuy));
    expect(noCharts.last.category, TransactionCategory.opening);
  });

  group('LedgerStatusRule', () {
    final occurred = DateTime.utc(2026, 11, 1, 12);
    TransactionStatus status(double roll, Duration age) =>
        LedgerStatusRule.statusFor(
          roll: roll,
          occurredAt: occurred,
          nowUtc: occurred.add(age),
        );

    test('young entries are mostly pending', () {
      const young = Duration(hours: 3);
      expect(status(0.1, young), TransactionStatus.pending);
      expect(status(0.7, young), TransactionStatus.completed);
      expect(status(0.93, young), TransactionStatus.completed);
      expect(status(0.97, young), TransactionStatus.failed);
    });

    test('old entries settle; a few completed ones get reversed', () {
      const old = Duration(days: 2);
      expect(status(0.1, old), TransactionStatus.completed);
      expect(status(0.7, old), TransactionStatus.completed);
      expect(status(0.93, old), TransactionStatus.reversed);
      expect(status(0.97, old), TransactionStatus.failed);
    });
  });

  group('SeededRandom', () {
    test('same key, same sequence; values in range', () {
      final a = SeededRandom.fromKey('fluxo');
      final b = SeededRandom.fromKey('fluxo');
      for (var i = 0; i < 100; i++) {
        final value = a.nextDouble();
        expect(value, b.nextDouble());
        expect(value, inInclusiveRange(0, 0.9999999999));
        expect(a.nextInt(10), b.nextInt(10));
      }
    });

    test('sequence is pinned across SDK versions', () {
      final random = SeededRandom(1);
      expect(
        [for (var i = 0; i < 3; i++) (random.nextDouble() * 1e6).floor()],
        [627073, 2735, 527447],
      );
    });

    test('different keys diverge and invalid bounds throw', () {
      expect(
        SeededRandom.fromKey('a').nextDouble(),
        isNot(SeededRandom.fromKey('b').nextDouble()),
      );
      expect(() => SeededRandom(1).nextInt(0), throwsArgumentError);
    });
  });
}
