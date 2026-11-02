import 'package:drift/drift.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';

/// Stores an enum as an explicit, stable code.
///
/// `Enum.name` is not used: release builds are obfuscated, and renaming an
/// enum value in code must not silently break rows already on the device.
/// Unknown codes throw, which the data source reports as a cache failure.
final class EnumCodeConverter<T extends Object>
    extends TypeConverter<T, String> {
  const new(this._codes);

  final Map<T, String> _codes;

  @override
  T fromSql(String fromDb) {
    for (final MapEntry(:key, :value) in _codes.entries) {
      if (value == fromDb) return key;
    }
    throw FormatException('Unknown code "$fromDb"');
  }

  @override
  String toSql(T value) => _codes[value]!;
}

const directionCodes = EnumCodeConverter<TransactionDirection>({
  TransactionDirection.credit: 'credit',
  TransactionDirection.debit: 'debit',
});

const statusCodes = EnumCodeConverter<TransactionStatus>({
  TransactionStatus.completed: 'completed',
  TransactionStatus.pending: 'pending',
  TransactionStatus.failed: 'failed',
  TransactionStatus.reversed: 'reversed',
});

const categoryCodes = EnumCodeConverter<TransactionCategory>({
  TransactionCategory.opening: 'opening',
  TransactionCategory.deposit: 'deposit',
  TransactionCategory.withdrawal: 'withdrawal',
  TransactionCategory.cryptoBuy: 'crypto_buy',
  TransactionCategory.cryptoSell: 'crypto_sell',
  TransactionCategory.fee: 'fee',
});
