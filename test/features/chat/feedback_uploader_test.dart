import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/data/feedback_uploader.dart';

void main() {
  late Directory directory;
  late FeedbackLog log;
  final endpoint = Uri.parse('https://feedback.example.test/ingest');

  setUp(() {
    directory = Directory.systemTemp.createTempSync('feedback_uploader_test');
    log = FeedbackLog(directoryProvider: () async => directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  FeedbackEvent event(int index) => FeedbackEvent(
    id: 'event_${index.toString().padLeft(3, '0')}',
    createdDay: '2026-11-20',
    appVersion: '1.0.0',
    locale: 'fil',
    query: 'magkano ₱ piña $index',
    routeKind: 'tool',
  );

  Future<List<FeedbackEvent>> appendEvents(int count) async {
    final events = [
      for (var index = 0; index < count; index += 1) event(index),
    ];
    for (final entry in events) {
      await log.append(entry);
    }
    return events;
  }

  List<String> requestIds(http.Request request) {
    final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
    return [
      for (final entry in body['events'] as List)
        (entry as Map)['id'] as String,
    ];
  }

  http.Response acceptAll(http.Request request) => http.Response(
    jsonEncode({'accepted': requestIds(request)}),
    200,
  );

  FeedbackUploader uploaderWith(
    Future<http.Response> Function(http.Request request) handler, {
    Uri? target,
  }) => FeedbackUploader(
    log: log,
    client: MockClient(handler),
    endpoint: target ?? endpoint,
  );

  test('null endpoint makes no request and does not read the log', () async {
    await appendEvents(2);
    var requests = 0;
    final uploader = FeedbackUploader(
      log: log,
      client: MockClient((request) async {
        requests += 1;
        return http.Response('', 200);
      }),
      endpoint: null,
    );
    final result = await uploader.uploadPending();
    expect(requests, 0);
    expect(result.sentCount, 0);
    expect(result.failed, isFalse);
    expect(await log.readAll(), hasLength(2));
  });

  test('empty log makes no request', () async {
    var requests = 0;
    final result = await uploaderWith((request) async {
      requests += 1;
      return http.Response('', 200);
    }).uploadPending();
    expect(requests, 0);
    expect(result.sentCount, 0);
    expect(result.failed, isFalse);
  });

  test('one chunk success removes events and counts accepted', () async {
    await appendEvents(3);
    final result = await uploaderWith((request) async => acceptAll(request))
        .uploadPending();
    expect(result.sentCount, 3);
    expect(result.failed, isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test(
    'request method, url, header and body match the specification',
    () async {
      final events = await appendEvents(2);
      final requests = <http.Request>[];
      await uploaderWith((request) async {
        requests.add(request);
        return acceptAll(request);
      }).uploadPending();
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url, endpoint);
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers.keys.map((key) => key.toLowerCase()).toSet(), {
        'content-type',
      });
      final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
      expect(body.keys.toList(), ['events']);
      expect(body['events'], [for (final entry in events) entry.toJson()]);
      expect(utf8.decode(request.bodyBytes), contains('₱ piña'));
    },
  );

  test('120 events go as 50, 50 and 20 oldest first', () async {
    final events = await appendEvents(120);
    final chunks = <List<String>>[];
    final result = await uploaderWith((request) async {
      chunks.add(requestIds(request));
      return acceptAll(request);
    }).uploadPending();
    expect(chunks.map((chunk) => chunk.length), [50, 50, 20]);
    expect(
      [for (final chunk in chunks) ...chunk],
      [
        for (final entry in events) entry.id,
      ],
    );
    expect(result.sentCount, 120);
    expect(result.failed, isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test('partially accepted chunk is still fully removed', () async {
    await appendEvents(4);
    final result = await uploaderWith(
      (request) async => http.Response(
        jsonEncode({
          'accepted': ['event_001', 'event_003', 'unknown_id'],
        }),
        200,
      ),
    ).uploadPending();
    expect(result.sentCount, 2);
    expect(result.failed, isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test('500 response keeps the events and reports failed', () async {
    await appendEvents(3);
    final result = await uploaderWith(
      (request) async => http.Response('boom', 500),
    ).uploadPending();
    expect(result.sentCount, 0);
    expect(result.failed, isTrue);
    expect(await log.readAll(), hasLength(3));
  });

  test('non-200 success status is a failure', () async {
    await appendEvents(1);
    final result = await uploaderWith(
      (request) async => http.Response('{"accepted":["event_000"]}', 204),
    ).uploadPending();
    expect(result.failed, isTrue);
    expect(await log.readAll(), hasLength(1));
  });

  test('failure on the second chunk keeps chunks two and three', () async {
    await appendEvents(120);
    var calls = 0;
    final result = await uploaderWith((request) async {
      calls += 1;
      if (calls == 2) return http.Response('boom', 503);
      return acceptAll(request);
    }).uploadPending();
    expect(calls, 2);
    expect(result.sentCount, 50);
    expect(result.failed, isTrue);
    final remaining = await log.readAll();
    expect(remaining, hasLength(70));
    expect(remaining.first.id, 'event_050');
    expect(remaining.last.id, 'event_119');
  });

  test(
    'client exception reports failed, removes nothing, never throws',
    () async {
      await appendEvents(3);
      final result = await uploaderWith(
        (request) async => throw const SocketException('offline'),
      ).uploadPending();
      expect(result.sentCount, 0);
      expect(result.failed, isTrue);
      expect(await log.readAll(), hasLength(3));
    },
  );

  test('timeout reports failed and removes nothing', () async {
    await appendEvents(3);
    final never = Completer<http.Response>();
    final uploader = uploaderWith((request) => never.future);
    final result = await runZoned(
      uploader.uploadPending,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) =>
            parent.createTimer(
              zone,
              duration == FeedbackUploader.requestTimeout
                  ? Duration.zero
                  : duration,
              callback,
            ),
      ),
    );
    expect(result.sentCount, 0);
    expect(result.failed, isTrue);
    expect(await log.readAll(), hasLength(3));
  });

  test('200 with garbage body removes the chunk with zero sent', () async {
    await appendEvents(3);
    final result = await uploaderWith(
      (request) async => http.Response('<html>not json', 200),
    ).uploadPending();
    expect(result.sentCount, 0);
    expect(result.failed, isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test('200 with wrong accepted shape counts zero', () async {
    await appendEvents(2);
    final result = await uploaderWith(
      (request) async => http.Response('{"accepted":"event_000"}', 200),
    ).uploadPending();
    expect(result.sentCount, 0);
    expect(result.failed, isFalse);
    expect(await log.readAll(), isEmpty);
  });

  test('concurrent calls share one set of requests', () async {
    await appendEvents(60);
    var requests = 0;
    final uploader = uploaderWith((request) async {
      requests += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return acceptAll(request);
    });
    final first = uploader.uploadPending();
    final second = uploader.uploadPending();
    expect(identical(first, second), isTrue);
    final results = await Future.wait([first, second]);
    expect(requests, 2);
    expect(results.first.sentCount, 60);
    expect(results.last.sentCount, 60);
  });

  test('a later call after completion uploads new events', () async {
    final uploader = uploaderWith((request) async => acceptAll(request));
    await appendEvents(1);
    expect((await uploader.uploadPending()).sentCount, 1);
    await log.append(event(7));
    expect((await uploader.uploadPending()).sentCount, 1);
  });
}
