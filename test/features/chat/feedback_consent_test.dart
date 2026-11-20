import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';

void main() {
  late Directory directory;
  late File consentFile;
  late FileFeedbackConsentStore store;
  late FeedbackLog log;
  late ProviderContainer container;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('feedback_consent_test');
    consentFile = File('${directory.path}/chat_feedback_consent.json');
    store = FileFeedbackConsentStore(directoryProvider: () async => directory);
    log = FeedbackLog(directoryProvider: () async => directory);
    container = ProviderContainer(
      overrides: [
        feedbackConsentStoreProvider.overrideWithValue(store),
        feedbackLogProvider.overrideWithValue(log),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    directory.deleteSync(recursive: true);
  });

  FeedbackEvent event(int index) => FeedbackEvent(
    id: 'event_$index',
    createdDay: '2026-11-20',
    appVersion: '1.0.0',
    locale: 'fil',
    query: 'magkano bigas $index',
    routeKind: 'tool',
  );

  Future<void> appendEvents() async {
    await log.append(event(1));
    await log.append(event(2));
  }

  group('store', () {
    test('reads false when no file exists', () async {
      expect(await store.read(), isFalse);
    });

    test('reads false for corrupt json', () async {
      consentFile.writeAsStringSync('{"granted": tr');
      expect(await store.read(), isFalse);
    });

    test('reads false for wrong shape', () async {
      consentFile.writeAsStringSync('[true]');
      expect(await store.read(), isFalse);
    });

    test('reads false for non-bool values', () async {
      for (final raw in ['"true"', '1', 'null', '"yes"']) {
        consentFile.writeAsStringSync('{"granted": $raw}');
        expect(await store.read(), isFalse, reason: raw);
      }
    });

    test('reads false when granted key is missing', () async {
      consentFile.writeAsStringSync('{"other": true}');
      expect(await store.read(), isFalse);
    });

    test('reads false when the path is a directory', () async {
      consentFile.createSync();
      consentFile.deleteSync();
      Directory(consentFile.path).createSync();
      expect(await store.read(), isFalse);
    });

    test('write true then read true', () async {
      await store.write(granted: true);
      expect(await store.read(), isTrue);
      expect(consentFile.readAsStringSync(), '{"granted":true}');
    });

    test('write false then read false', () async {
      await store.write(granted: true);
      await store.write(granted: false);
      expect(await store.read(), isFalse);
      expect(consentFile.readAsStringSync(), '{"granted":false}');
    });

    test('leaves no temporary file behind', () async {
      await store.write(granted: true);
      await store.write(granted: false);
      expect(File('${consentFile.path}.tmp').existsSync(), isFalse);
    });

    test('concurrent writes end with the last one', () async {
      await Future.wait([
        store.write(granted: true),
        store.write(granted: false),
        store.write(granted: true),
      ]);
      expect(await store.read(), isTrue);
    });
  });

  group('notifier', () {
    test('defaults to false', () async {
      expect(await container.read(feedbackConsentProvider.future), isFalse);
    });

    test('loads stored consent', () async {
      await store.write(granted: true);
      expect(await container.read(feedbackConsentProvider.future), isTrue);
    });

    test('state is AsyncData after granting and persists', () async {
      await container.read(feedbackConsentProvider.future);
      await container
          .read(feedbackConsentProvider.notifier)
          .setGranted(granted: true);
      expect(container.read(feedbackConsentProvider), const AsyncData(true));
      expect(await store.read(), isTrue);
    });

    test('state is AsyncData after revoking and persists', () async {
      await store.write(granted: true);
      await container.read(feedbackConsentProvider.future);
      await container
          .read(feedbackConsentProvider.notifier)
          .setGranted(granted: false);
      expect(container.read(feedbackConsentProvider), const AsyncData(false));
      expect(await store.read(), isFalse);
    });

    test('turning consent off clears the feedback log', () async {
      await appendEvents();
      expect(await log.readAll(), hasLength(2));
      await container.read(feedbackConsentProvider.future);
      await container
          .read(feedbackConsentProvider.notifier)
          .setGranted(granted: false);
      expect(await log.readAll(), isEmpty);
    });

    test('turning consent on keeps the feedback log', () async {
      await appendEvents();
      await container.read(feedbackConsentProvider.future);
      await container
          .read(feedbackConsentProvider.notifier)
          .setGranted(granted: true);
      expect(await log.readAll(), hasLength(2));
    });
  });
}
