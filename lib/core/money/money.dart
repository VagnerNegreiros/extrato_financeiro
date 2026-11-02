import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Thrown when a monetary operation would exceed the 64-bit integer range.
final class MoneyOverflowException implements Exception {
  const new(this.operation);

  final String operation;

  @override
  String toString() => 'MoneyOverflowException: $operation';
}

/// An amount of BRL stored as an integer number of cents (RN-01).
///
/// Integer cents are exact, fast and trivially serializable, which is why
/// `double` is never used for money. [Decimal] only appears at the boundary
/// where external prices are converted (see [Money.fromDecimal]).
///
/// The value may be negative (e.g. the net result of a period); transaction
/// amounts are kept positive by the entity itself (RN-02).
@immutable
final class Money implements Comparable<Money> {
  const new(this.cents);

  /// Converts an amount in reais to cents using half-even (banker's)
  /// rounding (RN-03): 0.125 -> 0.12 and 0.135 -> 0.14.
  factory fromDecimal(Decimal reais) {
    final scaled = reais.shift(2);
    final floor = scaled.floor();
    final fraction = scaled - floor;
    var cents = floor.toBigInt();
    if (fraction > _half || (fraction == _half && cents.isOdd)) {
      cents += BigInt.one;
    }
    if (!cents.isValidInt) {
      throw const MoneyOverflowException('fromDecimal');
    }
    return Money(cents.toInt());
  }

  /// Sums every amount, failing loudly instead of silently wrapping around.
  factory sum(Iterable<Money> amounts) =>
      amounts.fold(Money.zero, (total, amount) => total + amount);

  static const Money zero = Money(0);

  static final Decimal _half = Decimal.parse('0.5');

  final int cents;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  Money abs() => isNegative ? -this : this;

  Money operator +(Money other) {
    final result = cents + other.cents;
    // Two operands with the same sign can only produce a result with a
    // different sign when the 64-bit addition overflowed.
    if ((cents >= 0) == (other.cents >= 0) && (result >= 0) != (cents >= 0)) {
      throw const MoneyOverflowException('+');
    }
    return Money(result);
  }

  Money operator -(Money other) => this + -other;

  Money operator -() {
    // -minInt is not representable in 64 bits.
    if (cents == _minInt) throw const MoneyOverflowException('negate');
    return Money(-cents);
  }

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  /// Exact value in reais, for conversions that need decimal precision.
  Decimal toDecimal() => Decimal.fromInt(cents).shift(-2);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money($cents)';

  static const _minInt = -0x8000000000000000;
}
