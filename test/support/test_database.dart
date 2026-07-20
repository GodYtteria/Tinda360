import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tinda360/data/db/app_database.dart';

/// A real in-memory SQLite database with the app's schema, constraints and
/// foreign keys. Never a map-backed fake.
AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
    ),
  );
}
