const Duration defaultScanDebounceWindow = Duration(milliseconds: 1500);

class ScanDebouncer {
  new({
    this.window = defaultScanDebounceWindow,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  final Map<String, DateTime> _lastAcceptedAt = {};

  bool accept(String code) {
    final moment = _now();
    final previous = _lastAcceptedAt[code];
    if (previous != null && moment.difference(previous) < window) {
      return false;
    }
    _lastAcceptedAt[code] = moment;
    return true;
  }
}
