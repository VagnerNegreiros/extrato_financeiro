import 'package:extrato_financeiro/core/money/money.dart';

/// Formats [Money] in pt-BR (RN-04): `R$ 1.234,56`.
///
/// Formatting is done from the integer cents, so it never goes through
/// `double` (which `NumberFormat` would require) and stays exact for any
/// amount. A non-breaking space keeps the symbol and value on one line.
final class MoneyFormatter {
  const new();

  static const symbol = r'R$';
  static const _nbsp = ' ';
  static const _minus = '−';

  /// Shown instead of the amount when the user hides the balance.
  static const obscured = '$symbol$_nbsp••••••';

  /// `R$ 1.234,56`, or `−R$ 1.234,56` for negative amounts.
  String format(Money money) =>
      money.isNegative ? '$_minus${_body(money)}' : _body(money);

  /// Explicit sign for transaction amounts: `+R$ 10,00` / `−R$ 10,00`.
  String formatSigned(Money money, {required bool isCredit}) =>
      '${isCredit ? '+' : _minus}${_body(money)}';

  /// Text for screen readers, e.g. "1.234 reais e 56 centavos".
  String spoken(Money money) {
    final absCents = money.cents.abs();
    final reais = absCents ~/ 100;
    final cents = absCents % 100;
    final sign = money.isNegative ? 'menos ' : '';
    final reaisText = '${_group(reais)} ${reais == 1 ? 'real' : 'reais'}';
    if (cents == 0) return '$sign$reaisText';
    final centsText = '$cents ${cents == 1 ? 'centavo' : 'centavos'}';
    return '$sign$reaisText e $centsText';
  }

  String _body(Money money) {
    // BigInt avoids overflow when taking abs() of the minimum int value.
    final absCents = BigInt.from(money.cents).abs();
    final reais = absCents ~/ BigInt.from(100);
    final cents = (absCents % BigInt.from(100)).toString().padLeft(2, '0');
    return '$symbol$_nbsp${_groupDigits(reais.toString())},$cents';
  }

  String _group(int value) => _groupDigits(value.toString());

  String _groupDigits(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
