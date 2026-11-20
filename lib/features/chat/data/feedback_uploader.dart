import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'package:tinda360/features/chat/data/feedback_log.dart';

final class FeedbackUploadResult {
  const new({required this.sentCount, required this.failed});

  final int sentCount;
  final bool failed;
}

final class FeedbackUploader {
  new({required this.log, required this.client, required this.endpoint});

  static const int maximumEventsPerRequest = 50;
  static const Duration requestTimeout = Duration(seconds: 15);
  static const int _successStatus = 200;
  static const String _contentTypeHeader = 'content-type';
  static const String _jsonContentType = 'application/json';
  static const String _eventsKey = 'events';
  static const String _acceptedKey = 'accepted';

  final FeedbackLog log;
  final http.Client client;
  final Uri? endpoint;
  Future<FeedbackUploadResult>? _inFlight;

  Future<FeedbackUploadResult> uploadPending() {
    final running = _inFlight;
    if (running != null) return running;
    final started = _upload().whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  Future<FeedbackUploadResult> _upload() async {
    final target = endpoint;
    if (target == null) {
      return const FeedbackUploadResult(sentCount: 0, failed: false);
    }
    var sentCount = 0;
    try {
      final events = await log.readAll();
      for (
        var start = 0;
        start < events.length;
        start += maximumEventsPerRequest
      ) {
        final end = math.min(start + maximumEventsPerRequest, events.length);
        final queued = {
          for (final event in await log.readAll()) event.id: event,
        };
        final chunk = [
          for (final event in events.sublist(start, end))
            if (queued[event.id] case final current?) current,
        ];
        if (chunk.isEmpty) continue;
        final response = await _post(target, chunk);
        if (response.statusCode != _successStatus) {
          return FeedbackUploadResult(sentCount: sentCount, failed: true);
        }
        sentCount += _countAccepted(response, chunk);
        await log.removeAll([for (final event in chunk) event.id]);
      }
    } on Object {
      return FeedbackUploadResult(sentCount: sentCount, failed: true);
    }
    return FeedbackUploadResult(sentCount: sentCount, failed: false);
  }

  Future<http.Response> _post(Uri target, List<FeedbackEvent> chunk) {
    final body = jsonEncode(<String, Object>{
      _eventsKey: [for (final event in chunk) event.toJson()],
    });
    return client
        .post(
          target,
          headers: const <String, String>{
            _contentTypeHeader: _jsonContentType,
          },
          body: utf8.encode(body),
        )
        .timeout(requestTimeout);
  }

  int _countAccepted(http.Response response, List<FeedbackEvent> chunk) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return 0;
      final accepted = decoded[_acceptedKey];
      if (accepted is! List<dynamic>) return 0;
      final chunkIds = {for (final event in chunk) event.id};
      return accepted.whereType<String>().toSet().intersection(chunkIds).length;
    } on Object {
      return 0;
    }
  }
}
