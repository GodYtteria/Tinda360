import 'dart:io';

import 'package:tinda360/data/db/app_database.dart';

/// Measures the total disk bytes used by [databaseFile] and its WAL/SHM sidecars.
int measureDatabaseBytes(File databaseFile) {
  var totalBytes = 0;
  for (final path in [
    databaseFile.path,
    '${databaseFile.path}-wal',
    '${databaseFile.path}-shm',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      totalBytes += file.lengthSync();
    }
  }
  return totalBytes;
}

/// Formats a byte count into human-readable B / KB / MB text.
String formatByteCount(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(2)} MB';
}

/// Reclaims unused SQLite pages, truncates the WAL, and runs `PRAGMA optimize`.
Future<void> compactDatabase(AppDatabase database) async {
  final autoVacuumRows = await database
      .customSelect('PRAGMA auto_vacuum;')
      .get();
  final autoVacuumMode =
      autoVacuumRows.isNotEmpty ? autoVacuumRows.first.data.values.first as int? : null;
  if (autoVacuumMode != 2) {
    await database.customStatement('PRAGMA auto_vacuum = 2;');
    await database.customStatement('VACUUM;');
  } else {
    await database.customStatement('PRAGMA incremental_vacuum;');
  }
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  await database.customStatement('PRAGMA optimize;');
}

/// Writes a compacted single-file snapshot of [database] to [snapshotFile]
/// using `VACUUM INTO`, suitable for minimal-size Google Drive uploads.
Future<void> createCompactedBackupSnapshot(
  AppDatabase database,
  File snapshotFile,
) async {
  if (snapshotFile.path.contains('\x00')) {
    throw ArgumentError.value(snapshotFile.path, 'snapshotFile', 'Invalid path');
  }
  if (snapshotFile.existsSync()) {
    snapshotFile.deleteSync();
  }
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  final escapedPath = snapshotFile.path.replaceAll("'", "''");
  await database.customStatement("VACUUM INTO '$escapedPath';");
}
