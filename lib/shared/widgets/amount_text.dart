import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:flutter/material.dart';

/// The only widget that renders money, so every screen formats amounts
/// identically (RN-04).
///
/// With a [direction], the amount gets an explicit sign and the direction
/// color; the sign keeps credits and debits distinguishable without color.
class AmountText extends StatelessWidget {
  const new(
    this.amount, {
    this.direction,
    this.obscured = false,
    this.strikethrough = false,
    this.style,
    this.textAlign,
    super.key,
  });

  final Money amount;
  final TransactionDirection? direction;
  final bool obscured;

  /// For amounts without effect on the balance (failed, reversed).
  final bool strikethrough;
  final TextStyle? style;
  final TextAlign? textAlign;

  static const _formatter = MoneyFormatter();

  @override
  Widget build(BuildContext context) {
    final direction = this.direction;
    final text = obscured
        ? MoneyFormatter.obscured
        : direction == null
        ? _formatter.format(amount)
        : _formatter.formatSigned(amount, isCredit: direction.isCredit);

    return Semantics(
      label: semanticLabel(amount, direction: direction, obscured: obscured),
      excludeSemantics: true,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(
          color: obscured ? null : direction?.color(context),
          fontFeatures: tabularFigures,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  /// "Entrada de 150 reais", or "Valor oculto".
  static String semanticLabel(
    Money amount, {
    TransactionDirection? direction,
    bool obscured = false,
  }) {
    if (obscured) return 'Valor oculto';
    final spoken = _formatter.spoken(amount);
    return direction == null ? spoken : '${direction.label} de $spoken';
  }
}
