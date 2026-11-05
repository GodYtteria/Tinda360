import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final backupStatusStoreProvider = Provider<FileBackupStatusStore>(
  (ref) => FileBackupStatusStore(),
);

final class FileBackupStatusStore {
  FileBackupStatusStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'tinda360_backup_status.json';
  static const String _lastBackupKey = 'lastSuccessfulBackupMs';
  static const String _dismissedDayKey = 'warningDismissedDay';

  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  Future<DateTime?> readLastSuccessfulBackup() async {
    final value = (await _readMap())[_lastBackupKey];
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  Future<void> writeLastSuccessfulBackup(DateTime moment) => _updateMap(
    (map) => map[_lastBackupKey] = moment.toUtc().millisecondsSinceEpoch,
  );

  Future<String?> readWarningDismissedDay() async {
    final value = (await _readMap())[_dismissedDayKey];
    return value is String ? value : null;
  }

  Future<void> writeWarningDismissedDay(String dayKey) =>
      _updateMap((map) => map[_dismissedDayKey] = dayKey);

  Future<void> _updateMap(void Function(Map<String, dynamic> map) change) {
    final write = _lastWrite.then((_) async {
      final file = await _resolveFile();
      final map = await _readMap();
      change(map);
      await file.parent.create(recursive: true);
      final stagedFile = File('${file.path}.tmp');
      await stagedFile.writeAsString(jsonEncode(map), flush: true);
      await stagedFile.rename(file.path);
    });
    _lastWrite = write.catchError((Object error) {
      debugPrint('backup_status write failed: $error');
    });
    return write;
  }

  Future<Map<String, dynamic>> _readMap() async {
    try {
      final file = await _resolveFile();
      if (!file.existsSync()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{};
    } on Object catch (error) {
      debugPrint('backup_status read failed: $error');
      return <String, dynamic>{};
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}
