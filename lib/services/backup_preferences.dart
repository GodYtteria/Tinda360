import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

abstract interface class BackupPreferencesStore {
  Future<bool> readAutoBackupEnabled();

  Future<void> writeAutoBackupEnabled(bool enabled);

  Future<bool> readBackupConnected();

  Future<void> writeBackupConnected(bool connected);

  Future<String?> readConnectedEmail();

  Future<void> writeConnectedEmail(String? email);

  Future<String?> readLocaleCode();

  Future<void> writeLocaleCode(String code);
}

final class FileBackupPreferencesStore implements BackupPreferencesStore {
  FileBackupPreferencesStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'tinda360_backup_prefs.json';
  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  @override
  Future<bool> readAutoBackupEnabled() async =>
      await _readBool('autoBackupEnabled', defaultValue: true);

  @override
  Future<void> writeAutoBackupEnabled(bool enabled) async =>
      _writeField('autoBackupEnabled', enabled);

  @override
  Future<bool> readBackupConnected() async =>
      await _readBool('backupConnected', defaultValue: false);

  @override
  Future<void> writeBackupConnected(bool connected) async =>
      _writeField('backupConnected', connected);

  @override
  Future<String?> readConnectedEmail() async {
    final map = await _readMap();
    final value = map['connectedEmail'];
    return value is String ? value : null;
  }

  @override
  Future<void> writeConnectedEmail(String? email) => _updateMap((map) {
    if (email == null) {
      map.remove('connectedEmail');
    } else {
      map['connectedEmail'] = email;
    }
  });

  @override
  Future<String?> readLocaleCode() async {
    final map = await _readMap();
    final value = map['localeCode'];
    return value is String ? value : null;
  }

  @override
  Future<void> writeLocaleCode(String code) async =>
      _writeField('localeCode', code);

  Future<bool> _readBool(String key, {required bool defaultValue}) async {
    final map = await _readMap();
    final value = map[key];
    return value is bool ? value : defaultValue;
  }

  Future<void> _writeField(String key, Object value) =>
      _updateMap((map) => map[key] = value);

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
      debugPrint('backup_preferences write failed: $error');
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
    } on Object {
      return <String, dynamic>{};
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}
