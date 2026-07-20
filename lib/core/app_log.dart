/// A local-only error log. Boundaries record the original error and stack
/// here before returning a typed failure.
abstract interface class AppLog {
  /// Records [error] with its [stack] under a short dotted [event] name.
  void error(String event, Object error, StackTrace stack);
}
