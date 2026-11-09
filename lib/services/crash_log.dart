import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/core/app_log.dart';

final class CrashLog implements AppLog {
  new _(this._file);

  static Future<CrashLog> open() async {
    Directory directory;
    try {
      directory = await getApplicationSupportDirectory();
    } on Exception {
      directory = Directory.systemTemp;
    }
    return CrashLog._(File(p.join(directory.path, 'errors.log')));
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
        '$at $event ${redactBoundValues(error.toString())}\n$stack\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException {
      return;
    }
  }
}

final RegExp _boundValues = RegExp(
  '(parameters|args|arguments):.*',
  caseSensitive: false,
  dotAll: true,
);

String redactBoundValues(String message) => message.replaceAllMapped(
  _boundValues,
  (match) => '${match.group(1)}: [redacted]',
);
