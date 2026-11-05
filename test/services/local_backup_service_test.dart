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
    tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_backup_test_',
    );
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
      ..writeAsStringSync(
        'just some plain text that is over one hundred bytes long '
        'to pass the minimum length check for validation.',
      );
    expect(service.isValidSqliteBackup(textFile), isFalse);

    final wrongSchemaFile = File('${tempDirectory.path}/other.sqlite');
    sqlite3.open(wrongSchemaFile.path)
      ..execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY);')
      ..close();
    expect(service.isValidSqliteBackup(wrongSchemaFile), isFalse);
  });

  test('rejects a backup from a newer schema version', () {
    final newerFile = File('${tempDirectory.path}/newer.sqlite');
    sqlite3.open(newerFile.path)
      ..execute('CREATE TABLE products (id TEXT);')
      ..execute('CREATE TABLE sales (id TEXT);')
      ..execute('CREATE TABLE stock_movements (id TEXT);')
      ..execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1};',
      )
      ..close();
    expect(service.isValidSqliteBackup(newerFile), isFalse);
  });

  test('invalid import never closes the live database or touches it', () async {
    final targetFile = File('${tempDirectory.path}/live.sqlite')
      ..writeAsStringSync('live store data stays here');
    final badSource = File('${tempDirectory.path}/bad.sqlite')
      ..writeAsStringSync(
        'not a database, but long enough to pass the '
        'minimum length check of one hundred bytes for validation.',
      );
    var closeCalls = 0;
    var invalidateCalls = 0;

    await expectLater(
      service.importDatabaseFile(
        sourceFile: badSource,
        keepSourceFile: true,
        targetFile: targetFile,
        closeActiveDatabase: () async => closeCalls++,
        invalidateDatabase: () => invalidateCalls++,
      ),
      throwsFormatException,
    );

    expect(closeCalls, 0);
    expect(invalidateCalls, 0);
    expect(targetFile.readAsStringSync(), 'live store data stays here');
    expect(File('${targetFile.path}.importing').existsSync(), isFalse);
  });

  test('import keeps a safety copy of the replaced database', () async {
    final sourceFile = File('${tempDirectory.path}/source2.sqlite');
    final sourceDb = AppDatabase(NativeDatabase(sourceFile));
    await sourceDb.customSelect('SELECT 1;').get();
    final exportedBytes = await service.exportDatabaseBytes(
      database: sourceDb,
      databaseFile: sourceFile,
    );
    await sourceDb.close();
    final exportedFile = File('${tempDirectory.path}/exported2.sqlite')
      ..writeAsBytesSync(exportedBytes);
    final targetFile = File('${tempDirectory.path}/store.sqlite')
      ..writeAsStringSync('current live data');

    await service.importDatabaseFile(
      sourceFile: exportedFile,
      keepSourceFile: true,
      targetFile: targetFile,
      closeActiveDatabase: () async {},
      invalidateDatabase: () {},
    );

    final safetyCopy = File('${tempDirectory.path}/store.pre-import.sqlite');
    expect(safetyCopy.readAsStringSync(), 'current live data');
    expect(service.isValidSqliteBackup(targetFile), isTrue);
  });

  test('failed replace restores the previous database', () async {
    final sourceFile = File('${tempDirectory.path}/source3.sqlite');
    final sourceDb = AppDatabase(NativeDatabase(sourceFile));
    await sourceDb.customSelect('SELECT 1;').get();
    final exportedBytes = await service.exportDatabaseBytes(
      database: sourceDb,
      databaseFile: sourceFile,
    );
    await sourceDb.close();
    final exportedFile = File('${tempDirectory.path}/exported3.sqlite')
      ..writeAsBytesSync(exportedBytes);
    final targetFile = File('${tempDirectory.path}/blocked.sqlite')
      ..writeAsStringSync('keep me');

    await expectLater(
      service.importDatabaseFile(
        sourceFile: exportedFile,
        keepSourceFile: true,
        targetFile: targetFile,
        closeActiveDatabase: () async {
          File('${targetFile.path}.importing').deleteSync();
        },
        invalidateDatabase: () {},
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(targetFile.readAsStringSync(), 'keep me');
  });

  test(
    'exports compacted snapshot and imports valid Tinda360 backup',
    () async {
      final sourceFile = File('${tempDirectory.path}/source.sqlite');
      final targetFile = File('${tempDirectory.path}/target.sqlite')
        ..writeAsStringSync('old-placeholder');
      final targetWal = File('${targetFile.path}-wal')
        ..writeAsStringSync('wal');
      final targetShm = File('${targetFile.path}-shm')
        ..writeAsStringSync('shm');

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
        keepSourceFile: true,
        targetFile: targetFile,
        closeActiveDatabase: activeDb.close,
        invalidateDatabase: () => invalidated = true,
      );

      expect(invalidated, isTrue);
      expect(service.isValidSqliteBackup(targetFile), isTrue);
      expect(targetWal.existsSync(), isFalse);
      expect(targetShm.existsSync(), isFalse);
      expect(exportedFile.existsSync(), isTrue);

      final downloadedFile = File('${tempDirectory.path}/downloaded.sqlite')
        ..writeAsBytesSync(exportedBytes);
      final reopenedDb = AppDatabase(NativeDatabase(targetFile));
      await service.importDatabaseFile(
        sourceFile: downloadedFile,
        keepSourceFile: false,
        targetFile: targetFile,
        closeActiveDatabase: reopenedDb.close,
        invalidateDatabase: () {},
      );
      expect(downloadedFile.existsSync(), isFalse);
      expect(service.isValidSqliteBackup(targetFile), isTrue);
    },
  );
}
