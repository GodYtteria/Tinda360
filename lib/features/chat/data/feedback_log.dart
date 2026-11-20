import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum FeedbackRating { up, down }

final class FeedbackEvent {
  const new({
    required this.id,
    required this.createdDay,
    required this.appVersion,
    required this.locale,
    required this.query,
    required this.routeKind,
    this.toolName,
    this.confidence,
    this.chosenToolName,
    this.rating,
  });

  static const String _idKey = 'id';
  static const String _createdDayKey = 'created_day';
  static const String _appVersionKey = 'app_version';
  static const String _localeKey = 'locale';
  static const String _queryKey = 'query';
  static const String _routeKindKey = 'route_kind';
  static const String _toolKey = 'tool';
  static const String _confidenceKey = 'confidence';
  static const String _chosenToolKey = 'chosen_tool';
  static const String _ratingKey = 'rating';

  final String id;
  final String createdDay;
  final String appVersion;
  final String locale;
  final String query;
  final String routeKind;
  final String? toolName;
  final double? confidence;
  final String? chosenToolName;
  final FeedbackRating? rating;

  FeedbackEvent withRating(FeedbackRating rating) => FeedbackEvent(
    id: id,
    createdDay: createdDay,
    appVersion: appVersion,
    locale: locale,
    query: query,
    routeKind: routeKind,
    toolName: toolName,
    confidence: confidence,
    chosenToolName: chosenToolName,
    rating: rating,
  );

  FeedbackEvent withChosenTool(String chosenToolName) => FeedbackEvent(
    id: id,
    createdDay: createdDay,
    appVersion: appVersion,
    locale: locale,
    query: query,
    routeKind: routeKind,
    toolName: toolName,
    confidence: confidence,
    chosenToolName: chosenToolName,
    rating: rating,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    _idKey: id,
    _createdDayKey: createdDay,
    _appVersionKey: appVersion,
    _localeKey: locale,
    _queryKey: query,
    _routeKindKey: routeKind,
    if (toolName != null) _toolKey: toolName,
    if (confidence != null) _confidenceKey: confidence,
    if (chosenToolName != null) _chosenToolKey: chosenToolName,
    if (rating != null) _ratingKey: rating!.name,
  };

  static FeedbackEvent? fromJson(Map<String, Object?> json) {
    final id = json[_idKey];
    final createdDay = json[_createdDayKey];
    final appVersion = json[_appVersionKey];
    final locale = json[_localeKey];
    final query = json[_queryKey];
    final routeKind = json[_routeKindKey];
    final toolName = json[_toolKey];
    final confidence = json[_confidenceKey];
    final chosenToolName = json[_chosenToolKey];
    final ratingName = json[_ratingKey];
    final rating = ratingName is String
        ? FeedbackRating.values.asNameMap()[ratingName]
        : null;
    final requiredValid =
        id is String &&
        createdDay is String &&
        appVersion is String &&
        locale is String &&
        query is String &&
        routeKind is String;
    final optionalValid =
        (toolName == null || toolName is String) &&
        (confidence == null || confidence is num) &&
        (chosenToolName == null || chosenToolName is String) &&
        (ratingName == null || rating != null);
    if (!requiredValid || !optionalValid) return null;
    return FeedbackEvent(
      id: id,
      createdDay: createdDay,
      appVersion: appVersion,
      locale: locale,
      query: query,
      routeKind: routeKind,
      toolName: toolName as String?,
      confidence: (confidence as num?)?.toDouble(),
      chosenToolName: chosenToolName as String?,
      rating: rating,
    );
  }
}

final chatFeedbackDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);

final feedbackLogProvider = Provider<FeedbackLog>(
  (ref) => FeedbackLog(
    directoryProvider: ref.watch(chatFeedbackDirectoryProvider),
  ),
);

final class FeedbackLog {
  new({required this.directoryProvider});

  static const int maximumStoredEvents = 500;
  static const String _fileName = 'chat_feedback.json';

  final Future<Directory> Function() directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  Future<List<FeedbackEvent>> readAll() async => _load(await _resolveFile());

  Future<void> append(FeedbackEvent event) => _enqueue(() async {
    final file = await _resolveFile();
    final events = [...await _load(file), event];
    final overflow = events.length - maximumStoredEvents;
    await _save(file, overflow > 0 ? events.sublist(overflow) : events);
  });

  Future<void> setRating(String eventId, FeedbackRating rating) =>
      _update(eventId, (event) => event.withRating(rating));

  Future<void> setChosenTool(String eventId, String chosenToolName) =>
      _update(eventId, (event) => event.withChosenTool(chosenToolName));

  Future<void> removeAll(Iterable<String> eventIds) => _enqueue(() async {
    final file = await _resolveFile();
    final removed = eventIds.toSet();
    final events = await _load(file);
    final kept = [
      for (final event in events)
        if (!removed.contains(event.id)) event,
    ];
    if (kept.length == events.length) return;
    await _save(file, kept);
  });

  Future<void> clear() => _enqueue(() async {
    final file = await _resolveFile();
    if (file.existsSync()) await file.delete();
  });

  Future<void> _update(
    String eventId,
    FeedbackEvent Function(FeedbackEvent event) change,
  ) => _enqueue(() async {
    final file = await _resolveFile();
    final events = await _load(file);
    final index = events.indexWhere((event) => event.id == eventId);
    if (index < 0) return;
    events[index] = change(events[index]);
    await _save(file, events);
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final current = _lastWrite.catchError((Object _) {}).then((_) => action());
    _lastWrite = current;
    return current;
  }

  Future<List<FeedbackEvent>> _load(File file) async {
    if (!file.existsSync()) return <FeedbackEvent>[];
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return <FeedbackEvent>[];
    }
    if (decoded is! List<dynamic>) return <FeedbackEvent>[];
    final events = <FeedbackEvent>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final event = FeedbackEvent.fromJson(Map<String, Object?>.from(entry));
      if (event != null) events.add(event);
    }
    return events;
  }

  Future<void> _save(File file, List<FeedbackEvent> events) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode([for (final event in events) event.toJson()]),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _resolveFile() async {
    final directory = await directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}
