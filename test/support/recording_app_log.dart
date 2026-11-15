import 'package:tinda360/core/app_log.dart';

/// Collects logged errors so tests can assert that nothing failed silently.
final class RecordingAppLog implements AppLog {
  /// Every event recorded, in order.
  final List<String> events = [];

  @override
  void error(String event, Object error, StackTrace stack) => events.add(event);
}
