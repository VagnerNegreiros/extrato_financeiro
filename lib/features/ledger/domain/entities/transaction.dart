import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:meta/meta.dart';

/// Whether money enters (credit) or leaves (debit) the account.
enum TransactionDirection {
  credit,
  debit;

  bool get isCredit => this == credit;
}

/// Lifecycle of a transaction and its effect on the balance (RN-06/07).
enum TransactionStatus {
  completed,
  pending,
  failed,
  reversed;

  /// Only completed transactions are part of the period totals (RN-07).
  bool get countsInTotals => this == completed;
}

enum TransactionCategory {
  opening,
  deposit,
  withdrawal,
  cryptoBuy,
  cryptoSell,
  fee,
}

/// Optional details that depend on the category (e.g. crypto trades).
@immutable
final class TransactionMetadata {
  const new({
    this.assetId,
    this.assetSymbol,
    this.assetQuantity,
    this.unitPrice,
    this.counterparty,
  });

  static const empty = TransactionMetadata();

  /// CoinGecko id, e.g. `bitcoin`.
  final String? assetId;

  /// Ticker shown to the user, e.g. `BTC`.
  final String? assetSymbol;

  /// Exact quantity of the asset (8 decimal places).
  final Decimal? assetQuantity;

  /// Price of one unit of the asset when the transaction happened.
  final Money? unitPrice;

  final String? counterparty;

  bool get isEmpty =>
      assetId == null &&
      assetSymbol == null &&
      assetQuantity == null &&
      unitPrice == null &&
      counterparty == null;

  @override
  bool operator ==(Object other) =>
      other is TransactionMetadata &&
      other.assetId == assetId &&
      other.assetSymbol == assetSymbol &&
      other.assetQuantity == assetQuantity &&
      other.unitPrice == unitPrice &&
      other.counterparty == counterparty;

  @override
  int get hashCode =>
      Object.hash(assetId, assetSymbol, assetQuantity, unitPrice, counterparty);
}

/// A ledger entry. Invariants are enforced on construction, so an invalid
/// transaction cannot exist anywhere in the app.
@immutable
final class Transaction {
  /// Throws [ArgumentError] when an invariant is violated:
  /// * [id] and [description] must not be blank;
  /// * [amount] must be positive, the sign comes from [direction] (RN-02);
  /// * [occurredAt] must be a UTC instant (RN-10).
  factory({
    required String id,
    required String description,
    required Money amount,
    required TransactionDirection direction,
    required TransactionStatus status,
    required TransactionCategory category,
    required DateTime occurredAt,
    TransactionMetadata metadata = TransactionMetadata.empty,
  }) {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id', 'is blank');
    if (description.trim().isEmpty) {
      throw ArgumentError.value(description, 'description', 'is blank');
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
    if (!occurredAt.isUtc) {
      throw ArgumentError.value(occurredAt, 'occurredAt', 'must be UTC');
    }
    return Transaction._(
      id: id,
      description: description.trim(),
      amount: amount,
      direction: direction,
      status: status,
      category: category,
      occurredAt: occurredAt,
      metadata: metadata,
    );
  }

  const new _({
    required this.id,
    required this.description,
    required this.amount,
    required this.direction,
    required this.status,
    required this.category,
    required this.occurredAt,
    required this.metadata,
  });

  final String id;
  final String description;

  /// Always positive (RN-02); see [signedAmount].
  final Money amount;
  final TransactionDirection direction;
  final TransactionStatus status;
  final TransactionCategory category;

  /// UTC instant (RN-10).
  final DateTime occurredAt;
  final TransactionMetadata metadata;

  bool get isCredit => direction.isCredit;

  /// [amount] with the sign of its direction (credits positive).
  Money get signedAmount => isCredit ? amount : -amount;

  /// Statement ordering (RN-19): newest first, ties broken by id descending.
  static int newestFirst(Transaction a, Transaction b) {
    final byDate = b.occurredAt.compareTo(a.occurredAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  Transaction copyWith({TransactionStatus? status}) => Transaction._(
    id: id,
    description: description,
    amount: amount,
    direction: direction,
    status: status ?? this.status,
    category: category,
    occurredAt: occurredAt,
    metadata: metadata,
  );

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.description == description &&
      other.amount == amount &&
      other.direction == direction &&
      other.status == status &&
      other.category == category &&
      other.occurredAt == occurredAt &&
      other.metadata == metadata;

  @override
  int get hashCode => Object.hash(
    id,
    description,
    amount,
    direction,
    status,
    category,
    occurredAt,
    metadata,
  );

  // Amount and description are left out so logs never carry financial data.
  @override
  String toString() =>
      'Transaction($id, ${direction.name}, ${status.name}, '
      '${occurredAt.toIso8601String()})';
}
