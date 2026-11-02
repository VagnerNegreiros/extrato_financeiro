import 'dart:async';

import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/network/request_deduplicator.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/ledger/ledger_factory.dart';
import 'package:extrato_financeiro/features/ledger/data/local/ledger_local_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/local/page_cursor_codec.dart';
import 'package:extrato_financeiro/features/ledger/data/tracked_asset.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';

/// Offline-first ledger repository.
///
/// Reads only touch the local cache. [sync] fetches market data, derives the
/// ledger and replaces the cache atomically; while it runs, or when it
/// fails, screens keep showing the last known data.
final class TransactionRepositoryImpl implements TransactionRepository {
  new({
    required this._local,
    required this._remote,
    required this._clock,
    required this._logger,
    this._ledgerFactory = const LedgerFactory(),
    this.historyDays = 90,
  });

  /// Free API plans only serve one year of history.
  static const maxHistoryDays = 365;

  final LedgerLocalDataSource _local;
  final MarketDataSource _remote;
  final Clock _clock;
  final AppLogger _logger;
  final LedgerFactory _ledgerFactory;

  /// Length of the ledger created on the first sync.
  final int historyDays;

  final _syncDeduplicator = RequestDeduplicator<String, Result<SyncInfo>>();
  final _syncChanges = StreamController<SyncInfo>.broadcast();

  /// In-memory state, so failures are reported even though only successes
  /// are persisted. `null` until first read from the cache.
  SyncInfo? _syncInfo;

  @override
  Future<Result<TransactionPage>> getPage(
    TransactionQuery query, {
    PageCursor? cursor,
    int pageSize = TransactionPage.defaultSize,
  }) => _read(() async {
    if (pageSize < 1) throw const ParsingException('invalid page size');
    final after = cursor == null ? null : PageCursorCodec.decode(cursor);
    // One extra row tells whether another page exists without a second
    // query or an empty last page.
    final rows = await _local.queryPage(
      query,
      limit: pageSize + 1,
      after: after,
    );
    final hasMore = rows.length > pageSize;
    final items = List<Transaction>.unmodifiable(rows.take(pageSize));
    return TransactionPage(
      items: items,
      nextCursor: hasMore ? PageCursorCodec.encode(items.last) : null,
    );
  });

  @override
  Future<Result<Transaction>> getById(String id) async {
    final result = await _read(() => _local.findById(id));
    return switch (result) {
      Success(value: final transaction?) => Success(transaction),
      Success() => Err(NotFoundFailure(id)),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<List<Transaction>>> getAll() =>
      _read(() async => List.unmodifiable(await _local.findAll()));

  @override
  Future<Result<SyncInfo>> sync({bool force = false}) =>
      _syncDeduplicator.run('ledger', () => _sync(force: force));

  @override
  Stream<SyncInfo> watchSyncInfo() {
    late final StreamController<SyncInfo> controller;
    StreamSubscription<SyncInfo>? subscription;
    controller = StreamController<SyncInfo>(
      onListen: () {
        var receivedChange = false;
        // Subscribe first so no change is lost while the cache is read.
        subscription = _syncChanges.stream.listen((info) {
          receivedChange = true;
          controller.add(info);
        });
        _currentSyncInfo().then((info) {
          if (!receivedChange && !controller.isClosed) controller.add(info);
        }).ignore();
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<void> dispose() => _syncChanges.close();

  Future<Result<SyncInfo>> _sync({required bool force}) async {
    final current = await _currentSyncInfo();
    final now = _clock.nowUtc();
    if (!force && !current.needsRefresh(now)) return Success(current);

    _emit(current.copyWith(isSyncing: true));
    try {
      final metadata = await _local.readMetadata();
      final today = CalendarDate(now.year, now.month, now.day);
      final anchor = _anchorFor(metadata.anchor, today);
      // One extra day guarantees the anchor's 00:00 price is included.
      final days = anchor.daysUntil(today) + 2;

      final charts = await Future.wait([
        for (final asset in TrackedAsset.values)
          _remote.fetchDailyChart(asset.id, days: days),
      ]);
      final ledger = _ledgerFactory.build(
        charts: {
          for (final (index, asset) in TrackedAsset.values.indexed)
            asset: charts[index],
        },
        anchor: anchor,
        nowUtc: now,
      );
      await _local.replaceAll(ledger, syncedAt: now, anchor: anchor);

      final synced = SyncInfo(lastSuccessAt: now);
      _emit(synced);
      _logger.info('Ledger synced: ${ledger.length} transactions');
      return Success(synced);
    } on Object catch (error, stackTrace) {
      final failure = toFailure(error);
      _logger.warning('Ledger sync failed', error: error);
      if (failure is UnexpectedFailure) {
        _logger.error(
          'Unexpected sync error',
          error: error,
          stackTrace: stackTrace,
        );
      }
      _emit(
        SyncInfo(lastSuccessAt: current.lastSuccessAt, lastFailure: failure),
      );
      return Err(failure);
    }
  }

  /// The anchor is fixed on the first sync so past entries never change.
  /// After a year it slides forward, as older history is not available.
  CalendarDate _anchorFor(CalendarDate? stored, CalendarDate today) {
    final oldestAllowed = today.addDays(-(maxHistoryDays - 1));
    final anchor = stored ?? today.addDays(-(historyDays - 1));
    return anchor.isBefore(oldestAllowed) ? oldestAllowed : anchor;
  }

  Future<SyncInfo> _currentSyncInfo() async {
    final cached = _syncInfo;
    if (cached != null) return cached;
    try {
      final metadata = await _local.readMetadata();
      return _syncInfo ??= SyncInfo(lastSuccessAt: metadata.lastSuccessAt);
    } on CacheException catch (error) {
      _logger.warning('Could not read sync metadata', error: error);
      return SyncInfo.never;
    }
  }

  void _emit(SyncInfo info) {
    _syncInfo = info;
    if (!_syncChanges.isClosed) _syncChanges.add(info);
  }

  Future<Result<T>> _read<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      _logger.warning('Ledger read failed', error: error);
      return Err(toFailure(error));
    }
  }
}
