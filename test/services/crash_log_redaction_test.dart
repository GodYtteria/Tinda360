import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/services/crash_log.dart';

void main() {
  test('hides SQL bound values but keeps the error and statement', () {
    const message =
        'SqliteException(19): UNIQUE constraint failed\n'
        '  Causing statement: INSERT INTO customers (name, phone) VALUES (?, ?),'
        ' parameters: Maria Santos, 09171234567';

    final redacted = redactBoundValues(message);

    expect(redacted, contains('UNIQUE constraint failed'));
    expect(redacted, contains('INSERT INTO customers'));
    expect(redacted, contains('parameters: [redacted]'));
    expect(redacted, isNot(contains('Maria Santos')));
    expect(redacted, isNot(contains('09171234567')));
  });

  test('hides bound values that contain line breaks', () {
    const message =
        'SqliteException(19): failed\n'
        '  Causing statement: INSERT INTO t (note) VALUES (?),'
        ' parameters: unang linya\nikalawang linya 09171234567';

    final redacted = redactBoundValues(message);

    expect(redacted, contains('parameters: [redacted]'));
    expect(redacted, isNot(contains('unang linya')));
    expect(redacted, isNot(contains('ikalawang linya')));
    expect(redacted, isNot(contains('09171234567')));
  });

  test('leaves messages without bound values unchanged', () {
    expect(redactBoundValues('StateError: boom'), 'StateError: boom');
    expect(redactBoundValues(''), '');
  });
}
