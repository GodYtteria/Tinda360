import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/data/feedback_redactor.dart';
import 'package:tinda360/features/chat/data/feedback_uploader.dart';
import 'package:tinda360/services/service_providers.dart';

const String _configuredEndpoint = String.fromEnvironment(
  'TINDA360_FEEDBACK_ENDPOINT',
);
const String _appVersion = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: 'unknown',
);
const String _secureScheme = 'https';

final feedbackEndpointProvider = Provider<Uri?>((ref) {
  final endpoint = Uri.tryParse(_configuredEndpoint);
  final isUsable =
      endpoint != null &&
      endpoint.scheme == _secureScheme &&
      endpoint.host.isNotEmpty;
  return isUsable ? endpoint : null;
});

final feedbackHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final feedbackUploaderProvider = Provider<FeedbackUploader>(
  (ref) => FeedbackUploader(
    log: ref.watch(feedbackLogProvider),
    client: ref.watch(feedbackHttpClientProvider),
    endpoint: ref.watch(feedbackEndpointProvider),
  ),
);

final feedbackRecorderProvider = Provider<FeedbackRecorder>(
  (ref) => FeedbackRecorder(
    log: ref.watch(feedbackLogProvider),
    uploader: ref.watch(feedbackUploaderProvider),
    consentStore: ref.watch(feedbackConsentStoreProvider),
    clock: ref.watch(clockProvider),
    appLog: ref.watch(appLogProvider),
    appVersion: _appVersion,
  ),
);

final class FeedbackRecorder {
  new({
    required this.log,
    required this.uploader,
    required this.consentStore,
    required this.clock,
    required this.appLog,
    required this.appVersion,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const int _identifierBytes = 16;
  static const int _byteRange = 256;
  static const int _hexRadix = 16;
  static const int _hexDigitsPerByte = 2;
  static const int _dayFieldWidth = 2;
  static const int _yearFieldWidth = 4;
  static const String _padding = '0';

  final FeedbackLog log;
  final FeedbackUploader uploader;
  final FeedbackConsentStore consentStore;
  final Clock clock;
  final AppLog appLog;
  final String appVersion;
  final Random _random;

  Future<String?> record({
    required String query,
    required String locale,
    required String routeKind,
    required Iterable<String> customerNames,
    required Iterable<String> productNames,
    String? toolName,
    double? confidence,
  }) async {
    try {
      if (!await consentStore.read()) return null;
      final redactedQuery = const FeedbackRedactor().redact(
        query,
        customerNames: customerNames,
        productNames: productNames,
      );
      if (redactedQuery.trim().isEmpty) return null;
      final event = FeedbackEvent(
        id: _newIdentifier(),
        createdDay: _today(),
        appVersion: appVersion,
        locale: locale,
        query: redactedQuery,
        routeKind: routeKind,
        toolName: toolName,
        confidence: confidence,
      );
      await log.append(event);
      return event.id;
    } on Object catch (error, stack) {
      appLog.error('chat.feedback_record', error, stack);
      return null;
    }
  }

  Future<bool> rate(String eventId, FeedbackRating rating) =>
      _guarded('chat.feedback_rate', () => log.setRating(eventId, rating));

  Future<bool> recordChosenTool(String eventId, String toolName) => _guarded(
    'chat.feedback_choice',
    () => log.setChosenTool(eventId, toolName),
  );

  Future<void> uploadPending() async {
    try {
      if (!await consentStore.read()) return;
      await uploader.uploadPending();
    } on Object catch (error, stack) {
      appLog.error('chat.feedback_upload', error, stack);
    }
  }

  Future<bool> _guarded(String event, Future<void> Function() action) async {
    try {
      if (!await consentStore.read()) return false;
      await action();
      return true;
    } on Object catch (error, stack) {
      appLog.error(event, error, stack);
      return false;
    }
  }

  String _newIdentifier() => List<String>.generate(
    _identifierBytes,
    (index) => _random
        .nextInt(_byteRange)
        .toRadixString(_hexRadix)
        .padLeft(_hexDigitsPerByte, _padding),
  ).join();

  String _today() {
    final now = clock.now();
    final year = now.year.toString().padLeft(_yearFieldWidth, _padding);
    final month = now.month.toString().padLeft(_dayFieldWidth, _padding);
    final day = now.day.toString().padLeft(_dayFieldWidth, _padding);
    return '$year-$month-$day';
  }
}
