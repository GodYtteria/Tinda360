import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/time_greeting.dart';

void main() {
  test('returns Filipino and English greetings for all times of day', () {
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 7), isFilipino: true),
      'Magandang umaga!',
    );
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 12), isFilipino: true),
      'Magandang tanghali!',
    );
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 14), isFilipino: true),
      'Magandang hapon!',
    );
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 21), isFilipino: true),
      'Magandang gabi!',
    );
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 2), isFilipino: false),
      'Good evening!',
    );
    expect(
      timeOfDayGreeting(DateTime(2026, 11, 17, 9), isFilipino: false),
      'Good morning!',
    );
  });
}
