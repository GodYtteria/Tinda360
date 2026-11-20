import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:tinda360/features/chat/data/feedback_log.dart';

abstract interface class FeedbackConsentStore {
  Future<bool> read();

  Future<void> write({required bool granted});
}

final class FileFeedbackConsentStore implements FeedbackConsentStore {
  new({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'chat_feedback_consent.json';
  static const String _grantedKey = 'granted';

  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  @override
  Future<bool> read() async {
    try {
      final file = await _resolveFile();
      if (!file.existsSync()) return false;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      return decoded[_grantedKey] == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> write({required bool granted}) {
    final current = _lastWrite
        .catchError((Object _) {})
        .then((_) => _writeNow(granted));
    _lastWrite = current;
    return current;
  }

  Future<void> _writeNow(bool granted) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, bool>{_grantedKey: granted}),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}

final feedbackConsentStoreProvider = Provider<FeedbackConsentStore>(
  (ref) => FileFeedbackConsentStore(),
);

final feedbackConsentProvider =
    AsyncNotifierProvider<FeedbackConsentNotifier, bool>(
      FeedbackConsentNotifier.new,
    );

class FeedbackConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(feedbackConsentStoreProvider).read();

  Future<void> setGranted({required bool granted}) async {
    await ref.read(feedbackConsentStoreProvider).write(granted: granted);
    if (!granted) await ref.read(feedbackLogProvider).clear();
    state = AsyncData<bool>(granted);
  }
}
