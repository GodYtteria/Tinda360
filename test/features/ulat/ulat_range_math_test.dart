import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/features/ulat/presentation/ulat_range_math.dart';

LocalDay _day(int year, int month, int day) =>
    LocalDay.fromLocal(DateTime(year, month, day));

void main() {
  test('this month runs from the 1st to today', () {
    expect(
      thisMonthRange(_day(2026, 11, 18)),
      DayRange(_day(2026, 11, 1), _day(2026, 11, 18)),
    );
    expect(
      thisMonthRange(_day(2026, 11, 1)),
      DayRange.single(_day(2026, 11, 1)),
    );
  });

  test('last month is the full previous calendar month', () {
    expect(
      lastMonthRange(_day(2026, 11, 18)),
      DayRange(_day(2026, 10, 1), _day(2026, 10, 31)),
    );
    expect(
      lastMonthRange(_day(2026, 12, 1)),
      DayRange(_day(2026, 11, 1), _day(2026, 11, 30)),
    );
  });

  test('last month in January is December of the previous year', () {
    expect(
      lastMonthRange(_day(2027, 1, 9)),
      DayRange(_day(2026, 12, 1), _day(2026, 12, 31)),
    );
  });

  test('last month handles leap and non-leap February', () {
    expect(
      lastMonthRange(_day(2028, 3, 5)),
      DayRange(_day(2028, 2, 1), _day(2028, 2, 29)),
    );
    expect(
      lastMonthRange(_day(2027, 3, 5)),
      DayRange(_day(2027, 2, 1), _day(2027, 2, 28)),
    );
  });

  test('custom range rejects future end dates', () {
    final today = _day(2026, 11, 18);
    expect(
      isValidCustomRange(
        DayRange(_day(2026, 11, 1), _day(2026, 11, 19)),
        today,
      ),
      isFalse,
    );
    expect(
      isValidCustomRange(DayRange(_day(2026, 11, 1), today), today),
      isTrue,
    );
  });

  test('custom range allows 366 days but rejects 367', () {
    final today = _day(2028, 3, 1);
    final exactlyMax = DayRange(today.plusDays(-365), today);
    final tooLong = DayRange(today.plusDays(-366), today);
    expect(dayCountOf(exactlyMax), 366);
    expect(isValidCustomRange(exactlyMax, today), isTrue);
    expect(isValidCustomRange(tooLong, today), isFalse);
  });

  test('custom range rejects reversed range', () {
    final today = _day(2026, 11, 18);
    expect(
      isValidCustomRange(DayRange(today, today.plusDays(-1)), today),
      isFalse,
    );
  });

  test('picker result with time components maps to local days', () {
    final today = _day(2026, 11, 18);
    final range = customRangeFromPicker(
      start: DateTime(2026, 11, 1, 23, 59),
      end: DateTime(2026, 11, 18, 0, 1),
      today: today,
    );
    expect(range, DayRange(_day(2026, 11, 1), today));
    expect(
      customRangeFromPicker(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 19),
        today: today,
      ),
      isNull,
    );
  });

  test('dayRangeForPeriod uses the custom range for custom period', () {
    final today = _day(2026, 11, 18);
    final custom = DayRange(_day(2026, 10, 1), _day(2026, 10, 31));
    expect(
      dayRangeForPeriod(ReportPeriod.custom, today, customRange: custom),
      custom,
    );
    expect(
      dayRangeForPeriod(ReportPeriod.custom, today),
      DayRange.single(today),
    );
    expect(
      dayRangeForPeriod(ReportPeriod.week, today, customRange: custom),
      DayRange(today.plusDays(-6), today),
    );
  });

  test('dateOfLocalDay round trips', () {
    expect(dateOfLocalDay(_day(2028, 2, 29)), DateTime(2028, 2, 29));
  });
}
