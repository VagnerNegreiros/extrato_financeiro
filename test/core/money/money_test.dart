import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

Money _reais(String value) => Money.fromDecimal(Decimal.parse(value));

void main() {
  group('RN-01: money is integer cents', () {
    test('arithmetic is exact where double is not', () {
      // 0.1 + 0.2 != 0.3 in double; in cents it is exact.
      expect(const Money(10) + const Money(20), const Money(30));
      expect(const Money(100) - const Money(250), const Money(-150));
      expect(-const Money(5), const Money(-5));
      expect(const Money(-5).abs(), const Money(5));
    });

    test('comparison and predicates', () {
      expect(const Money(1) > Money.zero, isTrue);
      expect(const Money(-1) < Money.zero, isTrue);
      expect(const Money(3) >= const Money(3), isTrue);
      expect(const Money(3) <= const Money(2), isFalse);
      expect(Money.zero.isZero, isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(1).isPositive, isTrue);
      expect([const Money(3), const Money(1)]..sort(), [
        const Money(1),
        const Money(3),
      ]);
    });

    test('value semantics', () {
      expect(const Money(42), const Money(42));
      expect(const Money(42).hashCode, const Money(42).hashCode);
      expect(const Money(42), isNot(const Money(43)));
      expect(const Money(42).toString(), 'Money(42)');
      expect(
        const MoneyOverflowException('+').toString(),
        'MoneyOverflowException: +',
      );
    });

    test('toDecimal is exact', () {
      expect(const Money(123456).toDecimal(), Decimal.parse('1234.56'));
      expect(const Money(-1).toDecimal(), Decimal.parse('-0.01'));
    });
  });

  group('RN-03: half-even rounding from Decimal', () {
    test('ties go to the even cent', () {
      expect(_reais('0.125'), const Money(12));
      expect(_reais('0.135'), const Money(14));
      expect(_reais('0.145'), const Money(14));
      expect(_reais('2.5'), const Money(250));
    });

    test('non-ties round to nearest', () {
      expect(_reais('0.1251'), const Money(13));
      expect(_reais('0.1249'), const Money(12));
      expect(_reais('1234.567'), const Money(123457));
    });

    test('negative values are symmetric', () {
      expect(_reais('-0.125'), const Money(-12));
      expect(_reais('-0.135'), const Money(-14));
      expect(_reais('-0.1251'), const Money(-13));
    });

    test('price x quantity keeps precision', () {
      // 0.00012345 BTC at R$ 352.123,45 = R$ 43,469641...
      final value = Decimal.parse('0.00012345') * Decimal.parse('352123.45');
      expect(Money.fromDecimal(value), const Money(4347));
    });

    test('rejects values beyond 64-bit cents', () {
      expect(
        () => _reais('100000000000000000000'),
        throwsA(isA<MoneyOverflowException>()),
      );
    });
  });

  group('RN-05: large volumes', () {
    test(r'sums 100k transactions of ~R$ 10 million exactly', () {
      const amount = Money(999999999); // R$ 9.999.999,99
      final total = Money.sum(List.filled(100000, amount));
      expect(total, const Money(99999999900000));
    });

    test('sum of nothing is zero', () {
      expect(Money.sum(const []), Money.zero);
    });

    test('overflow throws instead of wrapping', () {
      const max = Money(0x7FFFFFFFFFFFFFFF);
      expect(
        () => max + const Money(1),
        throwsA(isA<MoneyOverflowException>()),
      );
      const min = Money(-0x8000000000000000);
      expect(
        () => min - const Money(1),
        throwsA(isA<MoneyOverflowException>()),
      );
      expect(() => -min, throwsA(isA<MoneyOverflowException>()));
    });

    test('mixed signs never overflow', () {
      const max = Money(0x7FFFFFFFFFFFFFFF);
      expect(max + const Money(-1), const Money(0x7FFFFFFFFFFFFFFE));
    });
  });
}
