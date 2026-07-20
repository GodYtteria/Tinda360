import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/database_maintenance.dart';

/// Validates, exports, and imports local `.sqlite` store database backups.
final class LocalBackupService {
  /// Creates a local backup service.
  const LocalBackupService();

  static const List<int> _sqliteMagicHeader = <int>[
    83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0,
  ];

  static const Set<String> _requiredTables = <String>{
    'products',
    'sales',
    'stock_movements',
  };

  /// Returns true when [candidateFile] is a valid Tinda360 SQLite database.
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
        return tableNames.containsAll(_requiredTables);
      } finally {
        database.close();
      }
    } on Object {
      return false;
    }
  }

  /// Creates a compacted single-file `.sqlite` snapshot and returns its bytes.
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
      if (snapshotFile.existsSync()) {
        return await snapshotFile.readAsBytes();
      }
      return await databaseFile.readAsBytes();
    } finally {
      if (snapshotFile.existsSync()) {
        snapshotFile.deleteSync();
      }
    }
  }

  /// Replaces [targetFile] with [sourceFile] after validating its schema.
  ///
  /// Throws [FormatException] if [sourceFile] is not a valid Tinda360 backup.
  Future<void> importDatabaseFile({
    required File sourceFile,
    required File targetFile,
    required Future<void> Function() closeActiveDatabase,
    required void Function() invalidateDatabase,
  }) async {
    if (!isValidSqliteBackup(sourceFile)) {
      throw const FormatException('invalid_sqlite_backup');
    }

    await closeActiveDatabase();
    final stagedFile = File('${targetFile.path}.importing');
    await sourceFile.copy(stagedFile.path);
    await stagedFile.rename(targetFile.path);
    _deleteSidecar('${targetFile.path}-wal');
    _deleteSidecar('${targetFile.path}-shm');
    invalidateDatabase();
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
