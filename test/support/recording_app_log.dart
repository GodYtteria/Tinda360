import 'package:tinda360/core/app_log.dart';

final class RecordingAppLog implements AppLog {
  final List<String> events = [];

  @override
  void error(String event, Object error, StackTrace stack) => events.add(event);
}
