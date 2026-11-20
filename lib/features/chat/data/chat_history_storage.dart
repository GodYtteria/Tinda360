import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final chatDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);

final chatHistoryStorageProvider = Provider<ChatHistoryStorage>(
  (ref) =>
      ChatHistoryStorage(directoryProvider: ref.watch(chatDirectoryProvider)),
);

final class ChatHistoryStorage {
  ChatHistoryStorage({required this.directoryProvider});

  static const int maxStoredMessages = 200;
  static final RegExp _unsafeCharacters = RegExp('[^A-Za-z0-9_-]');

  final Future<Directory> Function() directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  Future<List<Map<String, Object?>>> read(String storeId) async {
    final file = await _resolveFile(storeId);
    if (!file.existsSync()) return const <Map<String, Object?>>[];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<dynamic>) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final entry in decoded)
        if (entry is Map<String, dynamic>) Map<String, Object?>.from(entry),
    ];
  }

  Future<void> write(String storeId, List<Map<String, Object?>> messages) {
    final previous = _lastWrite;
    final current = previous
        .catchError((Object _) {})
        .then((_) => _writeNow(storeId, messages));
    _lastWrite = current;
    return current;
  }

  Future<void> _writeNow(
    String storeId,
    List<Map<String, Object?>> messages,
  ) async {
    final file = await _resolveFile(storeId);
    final kept = messages.length <= maxStoredMessages
        ? messages
        : messages.sublist(messages.length - maxStoredMessages);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(kept), flush: true);
    await temporary.rename(file.path);
  }

  Future<File> _resolveFile(String storeId) async {
    final directory = await directoryProvider();
    final safeId = storeId.replaceAll(_unsafeCharacters, '_');
    return File(path.join(directory.path, 'chat_history_$safeId.json'));
  }
}
