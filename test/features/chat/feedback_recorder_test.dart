import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/data/feedback_recorder.dart';
import 'package:tinda360/features/chat/data/feedback_uploader.dart';

import '../../support/recording_app_log.dart';

final class _MemoryConsentStore implements FeedbackConsentStore {
  new({required this.granted});

  bool granted;

  @override
  Future<bool> read() async => granted;

  @override
  Future<void> write({required bool granted}) async => this.granted = granted;
}

final class _RevokedAfterFirstReadConsentStore implements FeedbackConsentStore {
  int reads = 0;

  @override
  Future<bool> read() async => ++reads == 1;

  @override
  Future<void> write({required bool granted}) async {}
}

final class _ThrowingConsentStore implements FeedbackConsentStore {
  @override
  Future<bool> read() async => throw const FileSystemException('unreadable');

  @override
  Future<void> write({required bool granted}) async {}
}

void main() {
  late Directory directory;
  late FeedbackLog log;
  late List<http.Request> requests;
  late RecordingAppLog appLog;
  final endpoint = Uri.parse('https://feedback.example.test/v1/feedback');
  final identifierPattern = RegExp(r'^[a-f0-9]{32}$');

  setUp(() {
    directory = Directory.systemTemp.createTempSync('feedback_recorder_test');
    log = FeedbackLog(directoryProvider: () async => directory);
    requests = <http.Request>[];
    appLog = RecordingAppLog();
  });

  tearDown(() => directory.deleteSync(recursive: true));

  FeedbackRecorder recorderWith(
    FeedbackConsentStore consentStore, {
    http.Client? httpClient,
  }) {
    final client =
        httpClient ??
        MockClient((request) async {
          requests.add(request);
          final events =
              (jsonDecode(request.body) as Map<String, dynamic>)['events']
                  as List<dynamic>;
          return http.Response(
            jsonEncode({
              'accepted': [
                for (final event in events)
                  (event as Map<String, dynamic>)['id'],
              ],
            }),
            200,
          );
        });
    return FeedbackRecorder(
      log: log,
      uploader: FeedbackUploader(log: log, client: client, endpoint: endpoint),
      consentStore: consentStore,
      clock: Clock.fixed(DateTime(2026, 3, 7, 23, 59)),
      appLog: appLog,
      appVersion: '1.2.3',
      random: Random(7),
    );
  }

  Future<String?> recordUtangQuestion(FeedbackRecorder recorder) =>
      recorder.record(
        query: 'magkano utang ni Aling Nena sa Coke Zero, tawag 09171234567',
        locale: 'fil',
        routeKind: 'answerIntent',
        toolName: 'get_utang_list',
        confidence: 0.91,
        customerNames: ['Nena Cruz'],
        productNames: ['Coke Zero'],
      );

  group('without consent', () {
    test('nothing is recorded, rated or uploaded', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: false));
      expect(await recordUtangQuestion(recorder), isNull);
      expect(await log.readAll(), isEmpty);
      expect(await recorder.rate('anything', FeedbackRating.down), isFalse);
      await recorder.uploadPending();
      expect(requests, isEmpty);
    });

    test('consent turned off while recording leaves nothing stored', () async {
      final consentStore = _RevokedAfterFirstReadConsentStore();
      final recorder = recorderWith(consentStore);
      expect(await recordUtangQuestion(recorder), isNull);
      expect(consentStore.reads, 2);
      expect(await log.readAll(), isEmpty);
    });

    test(
      'events queued earlier are not uploaded once consent is off',
      () async {
        final consentStore = _MemoryConsentStore(granted: true);
        final recorder = recorderWith(consentStore);
        await recordUtangQuestion(recorder);
        consentStore.granted = false;
        await recorder.uploadPending();
        expect(requests, isEmpty);
      },
    );
  });

  group('with consent', () {
    test('the stored event is redacted and carries no extra fields', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final eventId = await recordUtangQuestion(recorder);
      expect(eventId, matches(identifierPattern));
      final stored = (await log.readAll()).single.toJson();
      expect(stored, {
        'id': eventId,
        'created_day': '2026-03-07',
        'app_version': '1.2.3',
        'locale': 'fil',
        'query':
            'magkano utang ni Aling <CUSTOMER> sa <PRODUCT>, tawag <NUMBER>',
        'route_kind': 'answerIntent',
        'tool': 'get_utang_list',
        'confidence': 0.91,
      });
      final fileText = File(
        '${directory.path}/chat_feedback.json',
      ).readAsStringSync();
      expect(fileText, isNot(contains('Nena')));
      expect(fileText, isNot(contains('0917')));
    });

    test('each event gets a different identifier', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final first = await recordUtangQuestion(recorder);
      final second = await recordUtangQuestion(recorder);
      expect(first, isNot(second));
    });

    test('a blank question is not recorded', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final eventId = await recorder.record(
        query: '   ',
        locale: 'en',
        routeKind: 'outOfScope',
        customerNames: const [],
        productNames: const [],
      );
      expect(eventId, isNull);
      expect(await log.readAll(), isEmpty);
    });

    test('a question longer than the server accepts is not recorded', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final atLimit = await recorder.record(
        query: 'a' * FeedbackRecorder.maximumQueryLength,
        locale: 'en',
        routeKind: 'askModel',
        customerNames: const [],
        productNames: const [],
      );
      final overLimit = await recorder.record(
        query: 'a' * (FeedbackRecorder.maximumQueryLength + 1),
        locale: 'en',
        routeKind: 'askModel',
        customerNames: const [],
        productNames: const [],
      );
      expect(atLimit, isNotNull);
      expect(overLimit, isNull);
      expect((await log.readAll()).single.id, atLimit);
    });

    test('rating and chosen tool update the stored event', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final eventId = (await recordUtangQuestion(recorder))!;
      expect(await recorder.rate(eventId, FeedbackRating.down), isTrue);
      expect(
        await recorder.recordChosenTool(eventId, 'get_utang_risk'),
        isTrue,
      );
      final stored = (await log.readAll()).single;
      expect(stored.rating, FeedbackRating.down);
      expect(stored.chosenToolName, 'get_utang_risk');
    });

    test('uploading sends the redacted events and empties the queue', () async {
      final recorder = recorderWith(_MemoryConsentStore(granted: true));
      final eventId = await recordUtangQuestion(recorder);
      await recorder.uploadPending();
      expect(requests, hasLength(1));
      expect(requests.single.url, endpoint);
      expect(requests.single.body, contains(eventId));
      expect(requests.single.body, isNot(contains('Nena')));
      expect(await log.readAll(), isEmpty);
    });
  });

  test('a failed upload keeps the queue and logs the error', () async {
    final recorder = recorderWith(
      _MemoryConsentStore(granted: true),
      httpClient: MockClient(
        (request) async => throw const SocketException('offline'),
      ),
    );
    await recordUtangQuestion(recorder);
    await recorder.uploadPending();
    expect(await log.readAll(), hasLength(1));
    expect(appLog.events, ['chat.feedback_upload']);
  });

  test('a failing consent store records nothing and logs the error', () async {
    final recorder = recorderWith(_ThrowingConsentStore());
    expect(await recordUtangQuestion(recorder), isNull);
    expect(await recorder.rate('anything', FeedbackRating.up), isFalse);
    await recorder.uploadPending();
    expect(requests, isEmpty);
    expect(appLog.events, [
      'chat.feedback_record',
      'chat.feedback_rate',
      'chat.feedback_upload',
    ]);
  });
}
