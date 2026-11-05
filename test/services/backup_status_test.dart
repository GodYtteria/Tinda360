import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/services/backup_status.dart';

void main() {
  late Directory directory;
  late FileBackupStatusStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('backup_status_test');
    store = FileBackupStatusStore(directoryProvider: () async => directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('empty store reads null', () async {
    expect(await store.readLastSuccessfulBackup(), isNull);
    expect(await store.readWarningDismissedDay(), isNull);
  });

  test('last backup round trips to the millisecond', () async {
    final moment = DateTime.utc(2026, 11, 18, 3, 4, 5, 6);
    await store.writeLastSuccessfulBackup(moment);
    expect(await store.readLastSuccessfulBackup(), moment);
  });

  test('dismissed day persists next to last backup', () async {
    await store.writeLastSuccessfulBackup(DateTime.utc(2026));
    await store.writeWarningDismissedDay('2026-11-18');
    expect(await store.readWarningDismissedDay(), '2026-11-18');
    expect(await store.readLastSuccessfulBackup(), DateTime.utc(2026));
  });

  test('corrupt file reads as empty', () async {
    File('${directory.path}/tinda360_backup_status.json').writeAsStringSync(
      'not json',
    );
    expect(await store.readLastSuccessfulBackup(), isNull);
  });
}
