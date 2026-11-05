import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/database_maintenance.dart';

final class LocalBackupService {
  const LocalBackupService();

  static const List<int> _sqliteMagicHeader = <int>[
    83,
    81,
    76,
    105,
    116,
    101,
    32,
    102,
    111,
    114,
    109,
    97,
    116,
    32,
    51,
    0,
  ];

  static const Set<String> _requiredTables = <String>{
    'products',
    'sales',
    'stock_movements',
  };

  bool isValidSqliteBackup(File candidateFile) {
    if (!candidateFile.existsSync()) return false;
    if (candidateFile.lengthSync() < 100) return false;
    if (!_hasSqliteMagicHeader(candidateFile)) return false;

    try {
      final database = sqlite3.open(
        candidateFile.path,
        mode: OpenMode.readOnly,
      );
      try {
        final rows = database.select(
          "SELECT name FROM sqlite_master WHERE type = 'table';",
        );
        final tableNames = <String>{
          for (final row in rows) row['name'] as String,
        };
        if (!tableNames.containsAll(_requiredTables)) return false;
        final userVersion = database.userVersion;
        if (userVersion > AppDatabase.currentSchemaVersion) return false;
        final integrity = database
            .select('PRAGMA quick_check;')
            .first
            .values
            .first;
        return integrity == 'ok';
      } finally {
        database.close();
      }
    } on Object {
      return false;
    }
  }

  Future<Uint8List> exportDatabaseBytes({
    required AppDatabase database,
    required File databaseFile,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final snapshotFile = File(
      '${Directory.systemTemp.path}/tinda360_local_export_$timestamp.sqlite',
    );
    try {
      await createCompactedBackupSnapshot(database, snapshotFile);
      if (!snapshotFile.existsSync()) {
        throw const FileSystemException('backup_snapshot_missing');
      }
      return await snapshotFile.readAsBytes();
    } finally {
      if (snapshotFile.existsSync()) {
        snapshotFile.deleteSync();
      }
    }
  }

  Future<void> importDatabaseFile({
    required File sourceFile,
    required bool keepSourceFile,
    required File targetFile,
    required Future<void> Function() closeActiveDatabase,
    required void Function() invalidateDatabase,
  }) async {
    final stagedFile = File('${targetFile.path}.importing');
    try {
      if (keepSourceFile) {
        await sourceFile.copy(stagedFile.path);
      } else {
        await sourceFile.rename(stagedFile.path);
      }
      if (!isValidSqliteBackup(stagedFile)) {
        throw const FormatException('invalid_sqlite_backup');
      }
      final safetyCopy = File(_preImportPath(targetFile));
      try {
        await closeActiveDatabase();
        _deleteSidecar('${targetFile.path}-wal');
        _deleteSidecar('${targetFile.path}-shm');
        final hadDatabase = targetFile.existsSync();
        if (hadDatabase) await targetFile.copy(safetyCopy.path);
        try {
          await stagedFile.rename(targetFile.path);
        } on Object {
          if (hadDatabase && safetyCopy.existsSync()) {
            await safetyCopy.copy(targetFile.path);
          }
          rethrow;
        }
      } finally {
        invalidateDatabase();
      }
    } finally {
      if (stagedFile.existsSync()) stagedFile.deleteSync();
      _deleteSidecar('${stagedFile.path}-wal');
      _deleteSidecar('${stagedFile.path}-shm');
    }
  }

  String _preImportPath(File targetFile) {
    final path = targetFile.path;
    final withoutExtension = path.endsWith('.sqlite')
        ? path.substring(0, path.length - '.sqlite'.length)
        : path;
    return '$withoutExtension.pre-import.sqlite';
  }

  bool _hasSqliteMagicHeader(File candidateFile) {
    final handle = candidateFile.openSync();
    try {
      final headerBytes = handle.readSync(_sqliteMagicHeader.length);
      if (headerBytes.length < _sqliteMagicHeader.length) return false;
      for (var index = 0; index < _sqliteMagicHeader.length; index++) {
        if (headerBytes[index] != _sqliteMagicHeader[index]) return false;
      }
      return utf8.decode(headerBytes.sublist(0, 15)) == 'SQLite format 3';
    } finally {
      handle.closeSync();
    }
  }

  void _deleteSidecar(String path) {
    final sidecar = File(path);
    if (sidecar.existsSync()) {
      sidecar.deleteSync();
    }
  }
}
