import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';

void main() {
  test('late-night and early-morning sales on the same date share a day', () {
    final morning = LocalDay.fromLocal(DateTime(2026, 11, 17, 0, 5));
    final night = LocalDay.fromLocal(DateTime(2026, 11, 17, 23, 55));
    expect(morning, night);
  });

  test('the next date is the next serial', () {
    final today = LocalDay.fromLocal(DateTime(2026, 11, 17));
    final tomorrow = LocalDay.fromLocal(DateTime(2026, 11, 18));
    expect(tomorrow, today.plusDays(1));
  });
}
