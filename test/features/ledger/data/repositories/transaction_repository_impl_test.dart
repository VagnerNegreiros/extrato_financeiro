import 'package:drift/native.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/local/app_database.dart';
import 'package:extrato_financeiro/features/ledger/data/local/ledger_local_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/repositories/transaction_repository_impl.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_market.dart';

void main() {
  late FixedClock clock;
  late AppDatabase db;
  late CountingMarket market;
  late TransactionRepositoryImpl repository;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 2, 15));
    db = AppDatabase(NativeDatabase.memory());
    market = CountingMarket(instantFakeMarket(clock));
    repository = TransactionRepositoryImpl(
      local: LedgerLocalDataSource(db),
      remote: market,
      clock: clock,
      logger: const AppLogger(enabled: false),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  group('sync', () {
    test('first sync builds the ledger from 3 chart requests', () async {
      final result = await repository.sync();

      expect(result.valueOrNull, SyncInfo(lastSuccessAt: clock.nowUtc()));
      expect(market.chartCalls, 3);
      final all = (await repository.getAll()).valueOrNull!;
      expect(all.length, greaterThan(100));
    });

    test(
      'RN-26: within the TTL an automatic sync does not hit the API',
      () async {
        await repository.sync();
        clock.advance(const Duration(minutes: 4));

        final result = await repository.sync();

        expect(result.isSuccess, isTrue);
        expect(market.chartCalls, 3);
      },
    );

    test('after the TTL, or when forced, it refreshes', () async {
      await repository.sync();
      await repository.sync(force: true);
      expect(market.chartCalls, 6);

      clock.advance(SyncInfo.ttl);
      await repository.sync();
      expect(market.chartCalls, 9);
    });

    test('concurrent syncs share a single request', () async {
      final results = await Future.wait([
        repository.sync(),
        repository.sync(force: true),
        repository.sync(),
      ]);

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(market.chartCalls, 3);
    });

    test('a failed sync keeps the cache and reports the failure', () async {
      await repository.sync();
      final before = (await repository.getAll()).valueOrNull!;
      market.errorToThrow = const RateLimitedException(
        retryAfter: Duration(seconds: 30),
      );
      clock.advance(const Duration(minutes: 20));

      final result = await repository.sync(force: true);

      expect(
        result.failureOrNull,
        const RateLimitFailure(retryAfter: Duration(seconds: 30)),
      );
      expect((await repository.getAll()).valueOrNull, before);
    });

    test('unknown errors become UnexpectedFailure', () async {
      market.errorToThrow = Exception('boom');
      expect((await repository.sync()).failureOrNull, isA<UnexpectedFailure>());
    });

    test('later syncs keep the anchor, so past ids are stable', () async {
      await repository.sync();
      final first = {
        for (final t in (await repository.getAll()).valueOrNull!) t.id: t,
      };

      clock.advance(const Duration(days: 3));
      await repository.sync();
      final second = {
        for (final t in (await repository.getAll()).valueOrNull!) t.id: t,
      };

      expect(second.length, greaterThan(first.length));
      for (final MapEntry(key: id, value: transaction) in first.entries) {
        expect(
          second[id]?.copyWith(status: transaction.status),
          transaction,
          reason: id,
        );
      }
    });
  });

  group('watchSyncInfo', () {
    test('emits the cached state first, then every change', () async {
      await repository.sync();
      final events = <SyncInfo>[];
      final subscription = repository.watchSyncInfo().listen(events.add);
      await pumpEventQueue();

      market.errorToThrow = const NetworkException();
      await repository.sync(force: true);
      await pumpEventQueue();
      await subscription.cancel();

      final syncedAt = clock.nowUtc();
      expect(events, [
        SyncInfo(lastSuccessAt: syncedAt),
        SyncInfo(lastSuccessAt: syncedAt, isSyncing: true),
        SyncInfo(lastSuccessAt: syncedAt, lastFailure: const NetworkFailure()),
      ]);
    });

    test('a fresh repository reads the last success from the cache', () async {
      await repository.sync();
      final reopened = TransactionRepositoryImpl(
        local: LedgerLocalDataSource(db),
        remote: market,
        clock: clock,
        logger: const AppLogger(enabled: false),
      );

      expect(
        await reopened.watchSyncInfo().first,
        SyncInfo(lastSuccessAt: clock.nowUtc()),
      );
      await reopened.dispose();
    });
  });

  group('reads', () {
    setUp(() => repository.sync());

    test('pages cover the whole statement exactly once, in order', () async {
      final all = (await repository.getAll()).valueOrNull!.toList()
        ..sort(Transaction.newestFirst);
      final collected = <Transaction>[];
      PageCursor? cursor;
      var pages = 0;
      do {
        final page = (await repository.getPage(
          TransactionQuery.all,
          cursor: cursor,
        )).valueOrNull!;
        expect(
          page.items.length,
          lessThanOrEqualTo(TransactionPage.defaultSize),
        );
        collected.addAll(page.items);
        cursor = page.nextCursor;
        pages++;
      } while (cursor != null);

      expect(collected, all);
      expect(pages, (all.length / TransactionPage.defaultSize).ceil());
    });

    test('an exact multiple of the page size has no empty last page', () async {
      final total = (await repository.getAll()).valueOrNull!.length;
      final page = (await repository.getPage(
        TransactionQuery.all,
        pageSize: total,
      )).valueOrNull!;
      expect(page.items, hasLength(total));
      expect(page.hasMore, isFalse);
    });

    test('invalid cursors and page sizes are parsing failures', () async {
      expect(
        (await repository.getPage(
          TransactionQuery.all,
          cursor: const PageCursor('not-a-cursor'),
        )).failureOrNull,
        isA<ParsingFailure>(),
      );
      expect(
        (await repository.getPage(
          TransactionQuery.all,
          pageSize: 0,
        )).failureOrNull,
        isA<ParsingFailure>(),
      );
    });

    test('getById finds cached transactions or reports not found', () async {
      final first = (await repository.getAll()).valueOrNull!.first;
      expect(await repository.getById(first.id), Success(first));
      expect(
        (await repository.getById('TX-00000000-00')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('a broken cache is reported as CacheFailure', () async {
      await db.customStatement('DROP TABLE transactions');
      expect((await repository.getAll()).failureOrNull, isA<CacheFailure>());
      expect(
        (await repository.getById('x')).failureOrNull,
        isA<CacheFailure>(),
      );
    });
  });
}
