import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/services/local_backup_service.dart';

void main() {
  const service = LocalBackupService();
  late Directory tempDirectory;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('tinda360_backup_test_');
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('rejects missing, non-sqlite, and wrong-schema sqlite files', () {
    final missingFile = File('${tempDirectory.path}/missing.sqlite');
    expect(service.isValidSqliteBackup(missingFile), isFalse);

    final textFile = File('${tempDirectory.path}/not_db.sqlite')
      ..writeAsStringSync('just some plain text that is over one hundred bytes long '
          'to pass the minimum length check for validation.');
    expect(service.isValidSqliteBackup(textFile), isFalse);

    final wrongSchemaFile = File('${tempDirectory.path}/other.sqlite');
    sqlite3.open(wrongSchemaFile.path)
      ..execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY);')
      ..close();
    expect(service.isValidSqliteBackup(wrongSchemaFile), isFalse);
  });

  test('exports compacted snapshot and imports valid Tinda360 backup', () async {
    final sourceFile = File('${tempDirectory.path}/source.sqlite');
    final targetFile = File('${tempDirectory.path}/target.sqlite')
      ..writeAsStringSync('old-placeholder');
    final targetWal = File('${targetFile.path}-wal')..writeAsStringSync('wal');
    final targetShm = File('${targetFile.path}-shm')..writeAsStringSync('shm');

    final sourceDb = AppDatabase(NativeDatabase(sourceFile));
    await sourceDb.customSelect('SELECT 1;').get();

    final exportedBytes = await service.exportDatabaseBytes(
      database: sourceDb,
      databaseFile: sourceFile,
    );
    await sourceDb.close();

    final exportedFile = File('${tempDirectory.path}/exported.sqlite')
      ..writeAsBytesSync(exportedBytes);
    expect(service.isValidSqliteBackup(exportedFile), isTrue);

    final activeDb = AppDatabase(NativeDatabase(targetFile));
    var invalidated = false;

    await service.importDatabaseFile(
      sourceFile: exportedFile,
      targetFile: targetFile,
      closeActiveDatabase: activeDb.close,
      invalidateDatabase: () => invalidated = true,
    );

    expect(invalidated, isTrue);
    expect(service.isValidSqliteBackup(targetFile), isTrue);
    expect(targetWal.existsSync(), isFalse);
    expect(targetShm.existsSync(), isFalse);
  });
}
