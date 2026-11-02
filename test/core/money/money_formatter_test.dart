import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

const _nbsp = ' ';
const _minus = '−';

void main() {
  const formatter = MoneyFormatter();

  group('RN-04: pt-BR formatting', () {
    test('formats with thousands separator and two decimals', () {
      expect(formatter.format(const Money(123456)), 'R\$${_nbsp}1.234,56');
      expect(formatter.format(Money.zero), 'R\$${_nbsp}0,00');
      expect(formatter.format(const Money(5)), 'R\$${_nbsp}0,05');
      expect(formatter.format(const Money(100)), 'R\$${_nbsp}1,00');
      expect(
        formatter.format(const Money(123456789012)),
        'R\$${_nbsp}1.234.567.890,12',
      );
    });

    test('negative amounts use the minus sign', () {
      expect(formatter.format(const Money(-150)), '${_minus}R\$${_nbsp}1,50');
    });

    test('signed format follows the transaction direction', () {
      expect(
        formatter.formatSigned(const Money(1000), isCredit: true),
        '+R\$${_nbsp}10,00',
      );
      expect(
        formatter.formatSigned(const Money(1000), isCredit: false),
        '${_minus}R\$${_nbsp}10,00',
      );
    });

    test('handles the extreme 64-bit values', () {
      expect(
        formatter.format(const Money(-0x8000000000000000)),
        '${_minus}R\$${_nbsp}92.233.720.368.547.758,08',
      );
    });

    test('obscured placeholder hides the amount', () {
      expect(MoneyFormatter.obscured, isNot(contains(RegExp(r'\d'))));
    });

    test('spoken text for screen readers', () {
      expect(
        formatter.spoken(const Money(123456)),
        '1.234 reais e 56 centavos',
      );
      expect(formatter.spoken(const Money(101)), '1 real e 1 centavo');
      expect(formatter.spoken(const Money(500)), '5 reais');
      expect(
        formatter.spoken(const Money(-250)),
        'menos 2 reais e 50 centavos',
      );
    });
  });
}
