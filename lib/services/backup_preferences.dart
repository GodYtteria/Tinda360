import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Persists device-level backup preferences (auto-backup and connection flag).
abstract interface class BackupPreferencesStore {
  /// Returns whether auto-backup is enabled (defaults to true).
  Future<bool> readAutoBackupEnabled();

  /// Saves the auto-backup enabled preference.
  Future<void> writeAutoBackupEnabled(bool enabled);

  /// Returns whether Google Drive backup was previously connected.
  Future<bool> readBackupConnected();

  /// Saves whether Google Drive backup is connected.
  Future<void> writeBackupConnected(bool connected);

  /// Returns the saved Google account email, or null if unset.
  Future<String?> readConnectedEmail();

  /// Saves the Google account email.
  Future<void> writeConnectedEmail(String? email);

  /// Returns saved app language code (`'en'` or `'fil'`), or null if unset.
  Future<String?> readLocaleCode();

  /// Saves the app language code (`'en'` or `'fil'`).
  Future<void> writeLocaleCode(String code);
}

/// JSON file implementation of [BackupPreferencesStore].
final class FileBackupPreferencesStore implements BackupPreferencesStore {
  /// Creates a file-backed backup preferences store.
  FileBackupPreferencesStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'tinda360_backup_prefs.json';
  final Future<Directory> Function() _directoryProvider;

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
  Future<void> writeConnectedEmail(String? email) async {
    if (email == null) {
      final file = await _resolveFile();
      final map = await _readMap();
      map.remove('connectedEmail');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(map));
      return;
    }
    await _writeField('connectedEmail', email);
  }

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

  Future<void> _writeField(String key, Object value) async {
    try {
      final file = await _resolveFile();
      final map = await _readMap();
      map[key] = value;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(map));
    } on Object {
      // Ignore storage errors in environments without writable support dir.
    }
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
