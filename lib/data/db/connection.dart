import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tinda360/data/db/store_registry.dart';

/// Resolves the on-device SQLite database file for the active store.
Future<File> databaseFile() async {
  final directory = await getApplicationSupportDirectory();
  final registry = await StoreRegistry.load(
    directoryProvider: () async => directory,
  );
  final fileName = StoreRegistry.isValidDatabaseFileName(
    registry.activeStore.fileName,
  )
      ? registry.activeStore.fileName
      : StoreRegistry.defaultFileName;
  return File(p.join(directory.path, fileName));
}

/// Opens the app database file lazily, on a background isolate.
QueryExecutor openConnection() => LazyDatabase(() async {
  sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

  final file = await databaseFile();
  return NativeDatabase.createInBackground(file, setup: applyPragmas);
});

/// Pragmas that must be set on every connection.
///
/// `foreign_keys` and `synchronous` are not stored in the file. WAL is, but
/// is set again so a freshly restored file adopts it.
void applyPragmas(Database raw) {
  final pageCount = raw.select('PRAGMA page_count;').first.columnAt(0) as int;
  if (pageCount == 0) {
    raw.execute('PRAGMA auto_vacuum = INCREMENTAL;');
  }
  raw
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA synchronous = FULL;')
    ..execute('PRAGMA foreign_keys = ON;')
    ..execute('PRAGMA busy_timeout = 5000;');
}
