import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';

void main() {
  late Directory directory;
  late FeedbackLog log;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('feedback_log_test');
    log = FeedbackLog(directoryProvider: () async => directory);
    file = File('${directory.path}/chat_feedback.json');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  FeedbackEvent event(int index) => FeedbackEvent(
    id: 'event_$index',
    createdDay: '2026-11-20',
    appVersion: '1.0.0',
    locale: 'fil',
    query: 'magkano ₱ piña $index',
    routeKind: 'tool',
  );

  Map<String, Object?> validJson() => event(1).toJson();

  List<Object?> storedJson() => jsonDecode(file.readAsStringSync()) as List;

  test('round trips with all fields', () {
    const full = FeedbackEvent(
      id: 'abc',
      createdDay: '2026-11-20',
      appVersion: '1.2.3',
      locale: 'en',
      query: 'magkano ₱ piña',
      routeKind: 'clarify',
      toolName: 'product_price',
      confidence: 0.75,
      chosenToolName: 'stock_check',
      rating: FeedbackRating.down,
    );
    final restored = FeedbackEvent.fromJson(
      jsonDecode(jsonEncode(full.toJson())) as Map<String, Object?>,
    )!;
    expect(restored.toJson(), full.toJson());
    expect(restored.query, 'magkano ₱ piña');
    expect(restored.confidence, 0.75);
    expect(restored.rating, FeedbackRating.down);
    expect(restored.chosenToolName, 'stock_check');
    expect(restored.toolName, 'product_price');
  });

  test('round trips with only required fields and omits null keys', () {
    final json = event(1).toJson();
    expect(json.keys.toSet(), {
      'id',
      'created_day',
      'app_version',
      'locale',
      'query',
      'route_kind',
    });
    final restored = FeedbackEvent.fromJson(json)!;
    expect(restored.toolName, isNull);
    expect(restored.confidence, isNull);
    expect(restored.chosenToolName, isNull);
    expect(restored.rating, isNull);
    expect(restored.toJson(), json);
  });

  test('wire keys are exactly the snake case names', () {
    final json = event(1)
        .withChosenTool('stock_check')
        .withRating(FeedbackRating.up)
        .toJson();
    final withOptional = FeedbackEvent.fromJson({
      ...json,
      'tool': 'product_price',
      'confidence': 1,
    })!;
    expect(withOptional.toJson().keys.toSet(), {
      'id',
      'created_day',
      'app_version',
      'locale',
      'query',
      'route_kind',
      'tool',
      'confidence',
      'chosen_tool',
      'rating',
    });
    expect(withOptional.toJson()['rating'], 'up');
    expect(withOptional.confidence, 1.0);
  });

  test('fromJson rejects missing required fields', () {
    for (final key in validJson().keys) {
      final json = validJson()..remove(key);
      expect(FeedbackEvent.fromJson(json), isNull, reason: key);
    }
  });

  test('fromJson rejects wrong typed fields', () {
    for (final key in validJson().keys) {
      final json = validJson()..[key] = 42;
      expect(FeedbackEvent.fromJson(json), isNull, reason: key);
    }
    expect(FeedbackEvent.fromJson({...validJson(), 'tool': 5}), isNull);
    expect(FeedbackEvent.fromJson({...validJson(), 'chosen_tool': 5}), isNull);
    expect(
      FeedbackEvent.fromJson({...validJson(), 'confidence': 'high'}),
      isNull,
    );
  });

  test('fromJson rejects unknown rating strings', () {
    expect(FeedbackEvent.fromJson({...validJson(), 'rating': 'meh'}), isNull);
    expect(FeedbackEvent.fromJson({...validJson(), 'rating': 1}), isNull);
  });

  test('missing file reads empty', () async {
    expect(await log.readAll(), isEmpty);
  });

  test('append keeps call order and unicode', () async {
    await log.append(event(1));
    await log.append(event(2));
    final stored = await log.readAll();
    expect(stored.map((item) => item.id), ['event_1', 'event_2']);
    expect(stored.first.query, 'magkano ₱ piña 1');
  });

  test('append keeps only the newest events over the cap', () async {
    await file.writeAsString(
      jsonEncode([
        for (var index = 0; index < FeedbackLog.maximumStoredEvents; index++)
          event(index).toJson(),
      ]),
    );
    await log.append(event(900));
    await log.append(event(901));
    final stored = await log.readAll();
    expect(stored.length, FeedbackLog.maximumStoredEvents);
    expect(stored.first.id, 'event_2');
    expect(stored.last.id, 'event_901');
    expect(stored[stored.length - 2].id, 'event_900');
  });

  test('twenty concurrent appends all land in order', () async {
    await Future.wait([
      for (var index = 0; index < 20; index++) log.append(event(index)),
    ]);
    final stored = await log.readAll();
    expect(stored.map((item) => item.id), [
      for (var index = 0; index < 20; index++) 'event_$index',
    ]);
  });

  test('setRating updates only the target', () async {
    await log.append(event(1));
    await log.append(event(2));
    await log.setRating('event_2', FeedbackRating.down);
    final stored = await log.readAll();
    expect(stored[0].rating, isNull);
    expect(stored[1].rating, FeedbackRating.down);
    expect(stored[1].query, event(2).query);
  });

  test('setChosenTool updates only the target', () async {
    await log.append(event(1));
    await log.append(event(2));
    await log.setChosenTool('event_1', 'stock_check');
    final stored = await log.readAll();
    expect(stored[0].chosenToolName, 'stock_check');
    expect(stored[1].chosenToolName, isNull);
  });

  test('unknown id is a no-op and creates no file', () async {
    await log.setRating('missing', FeedbackRating.up);
    await log.setChosenTool('missing', 'stock_check');
    await log.removeAll(['missing']);
    expect(file.existsSync(), isFalse);
  });

  test('unknown id leaves existing events untouched', () async {
    await log.append(event(1));
    await log.setRating('missing', FeedbackRating.up);
    await log.setChosenTool('missing', 'stock_check');
    final stored = await log.readAll();
    expect(stored.single.rating, isNull);
    expect(stored.single.chosenToolName, isNull);
  });

  test('removeAll removes only the given ids', () async {
    for (var index = 1; index <= 4; index++) {
      await log.append(event(index));
    }
    await log.removeAll(['event_2', 'event_4', 'unknown']);
    final stored = await log.readAll();
    expect(stored.map((item) => item.id), ['event_1', 'event_3']);
  });

  test('clear deletes the file and tolerates a missing file', () async {
    await log.clear();
    await log.append(event(1));
    expect(file.existsSync(), isTrue);
    await log.clear();
    expect(file.existsSync(), isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test('corrupt file reads empty and the next append replaces it', () async {
    await file.writeAsString('{not json');
    expect(await log.readAll(), isEmpty);
    await log.append(event(1));
    expect(storedJson().length, 1);
    expect((await log.readAll()).single.id, 'event_1');
  });

  test('valid json that is not an array reads empty', () async {
    await file.writeAsString('{"id":"event_1"}');
    expect(await log.readAll(), isEmpty);
    await log.append(event(2));
    expect(storedJson().length, 1);
  });

  test('array with one bad entry keeps the good ones', () async {
    await file.writeAsString(
      jsonEncode([
        event(1).toJson(),
        {'id': 'broken'},
        'text',
        event(3).toJson(),
      ]),
    );
    final stored = await log.readAll();
    expect(stored.map((item) => item.id), ['event_1', 'event_3']);
  });

  test('no temporary file is left after writes', () async {
    await log.append(event(1));
    await log.setRating('event_1', FeedbackRating.up);
    await log.setChosenTool('event_1', 'stock_check');
    await log.removeAll(['nothing']);
    final names = directory.listSync().map(
      (entity) => entity.uri.pathSegments.last,
    );
    expect(names, ['chat_feedback.json']);
  });
}
