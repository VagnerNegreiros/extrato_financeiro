import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';
import 'package:extrato_financeiro/features/ledger/data/ledger/seeded_random.dart';
import 'package:extrato_financeiro/features/ledger/data/tracked_asset.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';

/// Anti-corruption layer between CoinGecko market data and the ledger.
///
/// CoinGecko has no account statement, so the ledger is *derived*: real
/// daily BRL prices drive simulated deposits, withdrawals, crypto trades
/// and fees. Generation is deterministic:
///
/// * every day has its own PRNG seeded from the date, so a day's entries
///   never depend on how many days were requested;
/// * generation always starts at the same anchor day, so ids and amounts of
///   past days are stable across syncs (idempotent upserts, RN-28);
/// * only the status depends on `now`, so pending entries settle over time.
///
/// Debits are only generated when funded by credits that are at least two
/// days old and will settle, so the available balance never goes negative.
final class LedgerFactory {
  const new();

  static const openingBalance = Money(2000000); // R$ 20.000,00
  static const counterparty = 'Corretora Fluxo';

  static final Decimal _feeRate = Decimal.parse('0.005');
  static const _fundsDelayDays = 2;

  /// Builds every transaction from [anchor] to [nowUtc]'s day (UTC days).
  /// Entries scheduled after [nowUtc] are left out.
  List<Transaction> build({
    required Map<TrackedAsset, MarketChartDto> charts,
    required CalendarDate anchor,
    required DateTime nowUtc,
  }) {
    final dailyPrices = {
      for (final MapEntry(:key, :value) in charts.entries)
        key: _firstPricePerDay(value),
    };
    final today = CalendarDate(nowUtc.year, nowUtc.month, nowUtc.day);
    final state = _GenerationState();
    final transactions = <Transaction>[];

    for (var index = 0; !anchor.addDays(index).isAfter(today); index++) {
      final day = anchor.addDays(index);
      state.releaseFunds(index);
      final builder = _DayBuilder(
        date: day,
        dayIndex: index,
        state: state,
        nowUtc: nowUtc,
      );
      _generateDay(builder, dailyPrices);
      transactions.addAll(builder.transactions);
    }

    return transactions
        .where((transaction) => !transaction.occurredAt.isAfter(nowUtc))
        .toList()
      ..sort(Transaction.newestFirst);
  }

  void _generateDay(
    _DayBuilder day,
    Map<TrackedAsset, Map<CalendarDate, Decimal>> dailyPrices,
  ) {
    final random = day.random;

    if (day.dayIndex == 0) {
      day.add(
        description: 'Saldo inicial',
        amount: openingBalance,
        direction: TransactionDirection.credit,
        category: TransactionCategory.opening,
        alwaysCompleted: true,
      );
    }

    if (day.date.day == 5) {
      day.add(
        description: 'Depósito Pix · Salário',
        amount: Money((3000 + random.nextInt(61) * 50) * 100),
        direction: TransactionDirection.credit,
        category: TransactionCategory.deposit,
        counterparty: 'Empresa Exemplo Ltda',
      );
    } else if (random.nextDouble() < 0.10) {
      day.add(
        description: 'Pix recebido',
        amount: Money((100 + random.nextInt(141) * 10) * 100),
        direction: TransactionDirection.credit,
        category: TransactionCategory.deposit,
        counterparty: 'Conta Principal',
      );
    }

    if (random.nextDouble() < 0.05) {
      final amount = Money((100 + random.nextInt(91) * 10) * 100);
      if (day.state.canSpend(amount)) {
        day.add(
          description: 'Saque Pix',
          amount: amount,
          direction: TransactionDirection.debit,
          category: TransactionCategory.withdrawal,
          counterparty: 'Conta Principal',
        );
      }
    }

    for (final asset in TrackedAsset.values) {
      final price = dailyPrices[asset]?[day.date];
      if (price == null) continue;
      final roll = random.nextDouble();
      if (roll < 0.30) {
        _buy(day, asset, price);
      } else if (roll < 0.50) {
        _sell(day, asset, price);
      }
    }
  }

  void _buy(_DayBuilder day, TrackedAsset asset, Decimal price) {
    final target = Money((50 + day.random.nextInt(196) * 10) * 100);
    final quantity = (target.toDecimal() / price)
        .toDecimal(scaleOnInfinitePrecision: 12)
        .floor(scale: 8);
    final amount = Money.fromDecimal(quantity * price);
    final fee = _fee(amount);
    if (!amount.isPositive || !day.state.canSpend(amount + fee)) return;

    final settles = day.add(
      description: 'Compra de ${asset.displayName} (${asset.symbol})',
      amount: amount,
      direction: TransactionDirection.debit,
      category: TransactionCategory.cryptoBuy,
      asset: asset,
      quantity: quantity,
      unitPrice: Money.fromDecimal(price),
    );
    _chargeFee(day, asset, fee);
    if (settles) day.state.scheduleHolding(asset, quantity, day.dayIndex);
  }

  void _sell(_DayBuilder day, TrackedAsset asset, Decimal price) {
    final holding = day.state.holdingOf(asset);
    if (holding <= Decimal.zero) return;
    final fraction = Decimal.fromInt(10 + day.random.nextInt(51)).shift(-2);
    final quantity = (holding * fraction).floor(scale: 8);
    final amount = Money.fromDecimal(quantity * price);
    final fee = _fee(amount);
    if (!amount.isPositive || !day.state.canSpend(fee)) return;

    day.state.removeHolding(asset, quantity);
    day.add(
      description: 'Venda de ${asset.displayName} (${asset.symbol})',
      amount: amount,
      direction: TransactionDirection.credit,
      category: TransactionCategory.cryptoSell,
      asset: asset,
      quantity: quantity,
      unitPrice: Money.fromDecimal(price),
    );
    _chargeFee(day, asset, fee);
  }

  void _chargeFee(_DayBuilder day, TrackedAsset asset, Money fee) {
    day.add(
      description: 'Tarifa de corretagem · ${asset.symbol}',
      amount: fee,
      direction: TransactionDirection.debit,
      category: TransactionCategory.fee,
      asset: asset,
      // Charged right after the trade it belongs to.
      gapSeconds: 1,
    );
  }

  static Money _fee(Money amount) {
    final fee = Money.fromDecimal(amount.toDecimal() * _feeRate);
    return fee.isPositive ? fee : const Money(1);
  }

  /// The API returns one point per UTC day at 00:00 plus the current price;
  /// the first point of each day is the stable daily reference.
  static Map<CalendarDate, Decimal> _firstPricePerDay(MarketChartDto chart) {
    final result = <CalendarDate, Decimal>{};
    for (final point in chart.prices) {
      final t = point.timestamp;
      result.putIfAbsent(
        CalendarDate(t.year, t.month, t.day),
        () => point.price,
      );
    }
    return result;
  }
}

/// Funds and holdings available to the generator, tracked conservatively:
/// debits count immediately, credits only after they are sure to settle.
final class _GenerationState {
  Money _spendable = Money.zero;
  final _pendingFunds = <(int, Money)>[];
  final _holdings = <TrackedAsset, Decimal>{};
  final _pendingHoldings = <(int, TrackedAsset, Decimal)>[];

  bool canSpend(Money amount) => _spendable >= amount;

  void spend(Money amount) => _spendable -= amount;

  void scheduleFunds(Money amount, int fromDayIndex) =>
      _pendingFunds.add((fromDayIndex, amount));

  Decimal holdingOf(TrackedAsset asset) => _holdings[asset] ?? Decimal.zero;

  void scheduleHolding(TrackedAsset asset, Decimal quantity, int dayIndex) =>
      _pendingHoldings.add((
        dayIndex + LedgerFactory._fundsDelayDays,
        asset,
        quantity,
      ));

  void removeHolding(TrackedAsset asset, Decimal quantity) =>
      _holdings[asset] = holdingOf(asset) - quantity;

  void releaseFunds(int dayIndex) {
    _pendingFunds.removeWhere((entry) {
      if (entry.$1 > dayIndex) return false;
      _spendable += entry.$2;
      return true;
    });
    _pendingHoldings.removeWhere((entry) {
      if (entry.$1 > dayIndex) return false;
      _holdings[entry.$2] = holdingOf(entry.$2) + entry.$3;
      return true;
    });
  }
}

/// Creates the entries of one day with stable ids and increasing times.
final class _DayBuilder {
  new({
    required this.date,
    required this.dayIndex,
    required this.state,
    required this.nowUtc,
  }) : random = SeededRandom.fromKey('fluxo-ledger|$date'),
       _clock = DateTime.utc(date.year, date.month, date.day, 11);

  final CalendarDate date;
  final int dayIndex;
  final _GenerationState state;
  final DateTime nowUtc;
  final SeededRandom random;
  final transactions = <Transaction>[];

  // Entries happen between 11:00Z and 02:59Z (08:00-23:59 in Brasília).
  DateTime _clock;
  late final DateTime _lastSlot = DateTime.utc(
    date.year,
    date.month,
    date.day + 1,
    2,
    59,
  );

  /// Adds an entry and returns whether it will settle (eventually
  /// `completed`), which decides if its funds can be reused.
  bool add({
    required String description,
    required Money amount,
    required TransactionDirection direction,
    required TransactionCategory category,
    TrackedAsset? asset,
    Decimal? quantity,
    Money? unitPrice,
    String? counterparty,
    int? gapSeconds,
    bool alwaysCompleted = false,
  }) {
    final roll = alwaysCompleted ? 0.7 : random.nextDouble();
    final gap = gapSeconds != null
        ? Duration(seconds: gapSeconds)
        : Duration(minutes: 5 + random.nextInt(86));
    final next = _clock.add(gap);
    _clock = next.isAfter(_lastSlot) ? _lastSlot : next;

    final occurredAt = _clock;
    final settles = roll < LedgerStatusRule.settleThreshold;
    if (direction.isCredit) {
      if (settles) {
        state.scheduleFunds(
          amount,
          alwaysCompleted ? dayIndex : dayIndex + LedgerFactory._fundsDelayDays,
        );
      }
    } else {
      state.spend(amount);
    }

    transactions.add(
      Transaction(
        id:
            'TX-${_compact(date)}-'
            '${(transactions.length + 1).toString().padLeft(2, '0')}',
        description: description,
        amount: amount,
        direction: direction,
        status: alwaysCompleted
            ? TransactionStatus.completed
            : LedgerStatusRule.statusFor(
                roll: roll,
                occurredAt: occurredAt,
                nowUtc: nowUtc,
              ),
        category: category,
        occurredAt: occurredAt,
        metadata: TransactionMetadata(
          assetId: asset?.id,
          assetSymbol: asset?.symbol,
          assetQuantity: quantity,
          unitPrice: unitPrice,
          counterparty:
              counterparty ??
              (asset == null ? null : LedgerFactory.counterparty),
        ),
      ),
    );
    return settles;
  }

  static String _compact(CalendarDate date) =>
      date.toString().replaceAll('-', '');
}

/// Status of a generated entry from its fixed random roll and its age.
///
/// Young entries (up to one day old) are mostly pending; as they age,
/// pending ones settle as completed and a few completed ones get reversed.
/// Failed entries stay failed. The id never changes (RN-28).
abstract final class LedgerStatusRule {
  /// Rolls below this always end up completed.
  static const settleThreshold = 0.92;

  static TransactionStatus statusFor({
    required double roll,
    required DateTime occurredAt,
    required DateTime nowUtc,
  }) {
    if (roll >= 0.96) return TransactionStatus.failed;
    final isYoung = nowUtc.difference(occurredAt) <= const Duration(days: 1);
    if (isYoung) {
      return roll < 0.60
          ? TransactionStatus.pending
          : TransactionStatus.completed;
    }
    return roll < settleThreshold
        ? TransactionStatus.completed
        : TransactionStatus.reversed;
  }
}
