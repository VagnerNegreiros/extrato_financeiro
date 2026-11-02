import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/data/local/app_database.dart';
import 'package:extrato_financeiro/features/ledger/data/local/ledger_local_data_source.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/transaction_builder.dart';

void main() {
  late AppDatabase db;
  late LedgerLocalDataSource local;
  final syncedAt = DateTime.utc(2026, 11, 2, 12);
  final anchor = CalendarDate(2026, 8, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = LedgerLocalDataSource(db);
  });

  tearDown(() => db.close());

  Future<void> store(List<Transaction> transactions) =>
      local.replaceAll(transactions, syncedAt: syncedAt, anchor: anchor);

  test('round-trips every field, including exact decimals', () async {
    final trade = Transaction(
      id: 'TX-20261030-01',
      description: 'Compra de Bitcoin (BTC)',
      amount: const Money(4347),
      direction: TransactionDirection.debit,
      status: TransactionStatus.pending,
      category: TransactionCategory.cryptoBuy,
      occurredAt: DateTime.utc(2026, 10, 30, 17, 32, 5, 123),
      metadata: TransactionMetadata(
        assetId: 'bitcoin',
        assetSymbol: 'BTC',
        assetQuantity: Decimal.parse('0.00012345'),
        unitPrice: const Money(35212345),
        counterparty: 'Corretora Fluxo',
      ),
    );
    await store([trade, credit(100)]);

    expect(await local.findById(trade.id), trade);
    expect(await local.findAll(), hasLength(2));
    expect(await local.findById('missing'), isNull);
  });

  test('replaceAll swaps the whole snapshot and records metadata', () async {
    expect(await local.readMetadata(), (lastSuccessAt: null, anchor: null));

    await store([credit(1, at: DateTime.utc(2026, 10)), credit(2)]);
    final replacement = credit(3);
    await local.replaceAll(
      [replacement],
      syncedAt: syncedAt.add(const Duration(hours: 1)),
      anchor: anchor,
    );

    expect(await local.findAll(), [replacement]);
    expect(await local.readMetadata(), (
      lastSuccessAt: syncedAt.add(const Duration(hours: 1)),
      anchor: anchor,
    ));
  });

  group('queryPage', () {
    final base = DateTime.utc(2026, 10, 20, 12);
    // Same instant for a, b and c: ties are broken by id (RN-19).
    final a = tx(cents: 1, id: 'TX-A', at: base);
    final b = tx(cents: 1, id: 'TX-B', at: base);
    final c = tx(cents: 1, id: 'TX-C', at: base);
    final older = tx(
      cents: 1,
      id: 'TX-0',
      at: base.subtract(const Duration(days: 1)),
    );
    final newer = tx(
      cents: 1,
      id: 'TX-9',
      at: base.add(const Duration(days: 1)),
    );

    setUp(() => store([a, older, c, newer, b]));

    test('orders newest first with id as tie-breaker', () async {
      expect(await local.queryPage(TransactionQuery.all, limit: 10), [
        newer,
        c,
        b,
        a,
        older,
      ]);
    });

    test('keyset pagination resumes after ties without gaps', () async {
      final first = await local.queryPage(TransactionQuery.all, limit: 2);
      expect(first, [newer, c]);

      final second = await local.queryPage(
        TransactionQuery.all,
        limit: 2,
        after: (occurredAt: c.occurredAt, id: c.id),
      );
      expect(second, [b, a]);

      final third = await local.queryPage(
        TransactionQuery.all,
        limit: 2,
        after: (occurredAt: a.occurredAt, id: a.id),
      );
      expect(third, [older]);
    });
  });

  group('filters agree with TransactionQuery.matches', () {
    final saoPaulo = OffsetLocalCalendar.fixed(const Duration(hours: -3));
    final transactions = [
      tx(
        cents: 100,
        description: 'Depósito Pix · Salário',
        at: DateTime.utc(2026, 10, 5, 14),
      ),
      tx(
        cents: 200,
        description: 'Pix recebido',
        status: TransactionStatus.pending,
        at: DateTime.utc(2026, 10, 31, 23),
      ),
      tx(
        cents: 300,
        description: 'Compra de Bitcoin (BTC)',
        direction: TransactionDirection.debit,
        category: TransactionCategory.cryptoBuy,
        at: DateTime.utc(2026, 11, 1, 1),
      ),
      tx(
        cents: 400,
        description: 'Tarifa 100% _especial_',
        direction: TransactionDirection.debit,
        category: TransactionCategory.fee,
        status: TransactionStatus.failed,
        at: DateTime.utc(2026, 9),
      ),
      tx(
        cents: 500,
        description: 'Saque Pix',
        direction: TransactionDirection.debit,
        status: TransactionStatus.reversed,
        at: DateTime.utc(2026, 10, 15),
      ),
    ];

    final queries = <String, TransactionQuery>{
      'all': TransactionQuery.all,
      'debits': const TransactionQuery(direction: TransactionDirection.debit),
      'credits': const TransactionQuery(direction: TransactionDirection.credit),
      'pending or failed': const TransactionQuery(
        statuses: {TransactionStatus.pending, TransactionStatus.failed},
      ),
      'october in UTC-3': TransactionQuery(
        range: DateRange.localDays(
          CalendarDate(2026, 10, 1),
          CalendarDate(2026, 10, 31),
          saoPaulo,
        ),
      ),
      'accent-insensitive search': const TransactionQuery(
        searchTerm: 'deposito',
      ),
      'search pix': const TransactionQuery(searchTerm: 'pix'),
      'literal percent': const TransactionQuery(searchTerm: '100%'),
      'literal underscore': const TransactionQuery(searchTerm: '_especial_'),
      'percent is not a wildcard': const TransactionQuery(searchTerm: 'r%o'),
      'combined': TransactionQuery(
        direction: TransactionDirection.credit,
        statuses: const {TransactionStatus.pending},
        range: DateRange.localDays(
          CalendarDate(2026, 10, 31),
          CalendarDate(2026, 10, 31),
          saoPaulo,
        ),
        searchTerm: 'pix',
      ),
    };

    setUp(() => store(transactions));

    for (final MapEntry(key: name, value: query) in queries.entries) {
      test(name, () async {
        final expected = transactions.where(query.matches).toList()
          ..sort(Transaction.newestFirst);
        expect(await local.queryPage(query, limit: 50), expected);
      });
    }

    test('sanity: the edge cases actually select something', () async {
      expect(
        await local.queryPage(queries['literal percent']!, limit: 5),
        hasLength(1),
      );
      expect(
        await local.queryPage(queries['percent is not a wildcard']!, limit: 5),
        isEmpty,
      );
      expect(
        await local.queryPage(queries['combined']!, limit: 5),
        hasLength(1),
      );
    });
  });

  test('failures surface as CacheException', () async {
    // Simulates a corrupted cache; closing is not enough as drift reopens.
    await db.customStatement('DROP TABLE transactions');
    await expectLater(local.findAll(), throwsA(isA<CacheException>()));
    await expectLater(local.findById('x'), throwsA(isA<CacheException>()));
    await expectLater(
      local.queryPage(TransactionQuery.all, limit: 1),
      throwsA(isA<CacheException>()),
    );
    await expectLater(store([credit(1)]), throwsA(isA<CacheException>()));
  });
}
