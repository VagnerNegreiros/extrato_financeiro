import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';

part 'app_database.g.dart';

/// Ledger cache: the single source of truth of every screen (RN-24).
///
/// Enums are stored by name, so renaming an enum value requires a
/// migration. Instants are epoch milliseconds in UTC (RN-10).
@DataClassName('TransactionRow')
@TableIndex(name: 'idx_tx_occurred', columns: {#occurredAt, #id})
@TableIndex(name: 'idx_tx_status', columns: {#status})
@TableIndex(name: 'idx_tx_direction', columns: {#direction})
class TransactionRows extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get description => text()();

  /// Lower-case, accent-free copy of [description] used by the search.
  TextColumn get descriptionSearch => text()();
  IntColumn get amountCents => integer()();
  TextColumn get direction => textEnum<TransactionDirection>()();
  TextColumn get status => textEnum<TransactionStatus>()();
  TextColumn get category => textEnum<TransactionCategory>()();
  IntColumn get occurredAt => integer()();
  TextColumn get assetId => text().nullable()();
  TextColumn get assetSymbol => text().nullable()();

  /// Exact decimal quantity, stored as text to keep every digit.
  TextColumn get assetQuantity => text().nullable()();
  IntColumn get unitPriceCents => integer().nullable()();
  TextColumn get counterparty => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Amounts are positive; the sign comes from the direction (RN-02).
  @override
  List<String> get customConstraints => ['CHECK (amount_cents > 0)'];
}

@DataClassName('SyncMetadataRow')
class SyncMetadataRows extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get resource => text()();
  IntColumn get lastSuccessAt => integer().nullable()();

  /// First day of the generated ledger (`yyyy-mm-dd`), fixed on first sync.
  TextColumn get anchorDay => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {resource};
}

@DriftDatabase(tables: [TransactionRows, SyncMetadataRows])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// On-device database file.
  factory open() => AppDatabase(driftDatabase(name: 'fluxo'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (migrator) => migrator.createAll());
}
