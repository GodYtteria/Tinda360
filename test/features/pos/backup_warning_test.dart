import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/pos/data/backup_warning.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);

  bool warn({
    required bool connected,
    DateTime? last,
    int sales = 0,
  }) => shouldWarnAboutBackup(
    backupConnected: connected,
    lastSuccessfulBackup: last,
    saleCount: sales,
    now: now,
  );

  test('never connected with few sales does not warn', () {
    expect(warn(connected: false, sales: 19), isFalse);
  });

  test('never connected with 20 sales warns', () {
    expect(warn(connected: false, sales: 20), isTrue);
  });

  test('connected and stale warns', () {
    expect(
      warn(connected: true, last: now.subtract(const Duration(days: 8))),
      isTrue,
    );
  });

  test('connected and fresh does not warn', () {
    expect(
      warn(connected: true, last: now.subtract(const Duration(days: 2))),
      isFalse,
    );
  });

  test('exactly 7 days does not warn, one minute more does', () {
    expect(
      warn(connected: true, last: now.subtract(const Duration(days: 7))),
      isFalse,
    );
    expect(
      warn(
        connected: true,
        last: now.subtract(const Duration(days: 7, minutes: 1)),
      ),
      isTrue,
    );
  });

  test('connected with no recorded backup warns', () {
    expect(warn(connected: true), isTrue);
  });

  test('day key is zero padded', () {
    expect(backupWarningDayKey(DateTime(2026, 3, 5, 9)), '2026-03-05');
  });
}
