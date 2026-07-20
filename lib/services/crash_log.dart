import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/core/app_log.dart';

/// A small, local-only error log file. Writes are synchronous so an entry
/// survives a hard crash, and the file is cleared once it grows too large.
final class CrashLog implements AppLog {
  CrashLog._(this._file);

  /// Opens (or creates) the log in the app's private support directory.
  static Future<CrashLog> open() async {
    final dir = await getApplicationSupportDirectory();
    return CrashLog._(File(p.join(dir.path, 'errors.log')));
  }

  static const int _maxBytes = 256 * 1024;

  final File _file;

  @override
  void error(String event, Object error, StackTrace stack) {
    try {
      if (_file.existsSync() && _file.lengthSync() > _maxBytes) {
        _file.writeAsStringSync('');
      }
      final at = clock.now().toUtc().toIso8601String();
      _file.writeAsStringSync(
        '$at $event $error\n$stack\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException {
      return;
    }
  }
}
