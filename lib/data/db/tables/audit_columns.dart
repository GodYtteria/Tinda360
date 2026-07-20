import 'package:drift/drift.dart';

/// Columns every table carries: a UUID key, UTC-millisecond timestamps, a
/// revision counter, and a soft-delete flag.
mixin AuditColumns on Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// When the row was created, UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// When the row last changed, UTC epoch milliseconds.
  IntColumn get updatedAt => integer()();

  /// Incremented on every update.
  IntColumn get rowRevision => integer().withDefault(const Constant(0))();

  /// Soft-delete flag; every read filters on it.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// When the row was soft-deleted, UTC epoch milliseconds.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
