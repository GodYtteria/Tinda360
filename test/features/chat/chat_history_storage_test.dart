import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/chat_history_storage.dart';

void main() {
  late Directory directory;
  late ChatHistoryStorage storage;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('chat_history_test');
    storage = ChatHistoryStorage(directoryProvider: () async => directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Map<String, Object?> message(int index) => <String, Object?>{
    'id': 'user_$index',
    'role': 'user',
    'text': 'magkano ₱$index?',
    'source': null,
    'created_at_ms': index,
  };

  test('round trips messages including unicode', () async {
    await storage.write('store_a', [message(1), message(2)]);
    final restored = await storage.read('store_a');
    expect(restored, [message(1), message(2)]);
  });

  test('missing file reads as empty', () async {
    expect(await storage.read('store_a'), isEmpty);
  });

  test('keeps only the newest messages when over the limit', () async {
    final many = [for (var i = 0; i < 250; i++) message(i)];
    await storage.write('store_a', many);
    final restored = await storage.read('store_a');
    expect(restored.length, ChatHistoryStorage.maxStoredMessages);
    expect(restored.last['id'], 'user_249');
    expect(restored.first['id'], 'user_50');
  });

  test('stores are isolated and unsafe ids are sanitized', () async {
    await storage.write('../evil', [message(1)]);
    await storage.write('store_b', [message(2)]);
    expect((await storage.read('store_b')).single['id'], 'user_2');
    expect(
      directory.listSync().every(
        (entity) => entity.path.startsWith(directory.path),
      ),
      isTrue,
    );
  });

  test('concurrent writes all succeed and the last call wins', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++)
        storage.write('store_a', [for (var j = 0; j <= i; j++) message(j)]),
    ]);
    final restored = await storage.read('store_a');
    expect(restored.length, 20);
    expect(restored.last['id'], 'user_19');
    expect(
      directory.listSync().where((entity) => entity.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('corrupt file throws instead of returning bad data', () async {
    File('${directory.path}/chat_history_store_a.json')
        .writeAsStringSync('{not json');
    expect(storage.read('store_a'), throwsA(isA<FormatException>()));
  });
}
