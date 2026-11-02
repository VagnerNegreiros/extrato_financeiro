import 'dart:convert';

import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/features/ledger/data/local/ledger_local_data_source.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';

/// Encodes the keyset position into an opaque cursor (RN-21), so callers
/// cannot depend on (or tamper with) its structure.
abstract final class PageCursorCodec {
  static PageCursor encode(Transaction last) => PageCursor(
    base64Url.encode(
      utf8.encode('${last.occurredAt.millisecondsSinceEpoch}|${last.id}'),
    ),
  );

  /// Throws [ParsingException] for cursors this codec did not produce.
  static StatementPosition decode(PageCursor cursor) {
    try {
      final decoded = utf8.decode(base64Url.decode(cursor.value));
      final separator = decoded.indexOf('|');
      final millis = int.parse(decoded.substring(0, separator));
      final id = decoded.substring(separator + 1);
      if (id.isEmpty) throw const FormatException('empty id');
      return (
        occurredAt: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
        id: id,
      );
    } on Object {
      throw const ParsingException('invalid page cursor');
    }
  }
}
