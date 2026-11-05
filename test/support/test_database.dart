import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tinda360/data/db/app_database.dart';

AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
    ),
  );
}
