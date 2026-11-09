import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/services/backup_file_name.dart';

void main() {
  final day = DateTime(2026, 11, 18, 17, 30);

  test('uses the store name and the date', () {
    expect(
      backupFileNameFor('Tindahan ni Aling Nena', day),
      'Tinda360-Tindahan-ni-Aling-Nena-2026-11-18.sqlite',
    );
  });

  test('turns accents and unsafe characters into plain letters', () {
    expect(
      backupFileNameFor("Ñora's / Tindahan: #1?", day),
      'Tinda360-Nora-s-Tindahan-1-2026-11-18.sqlite',
    );
  });

  test('falls back when the name is blank or only symbols', () {
    expect(backupFileNameFor('', day), 'Tinda360-Tindahan-2026-11-18.sqlite');
    expect(
      backupFileNameFor('   ', day),
      'Tinda360-Tindahan-2026-11-18.sqlite',
    );
    expect(
      backupFileNameFor('🏪🏪', day),
      'Tinda360-Tindahan-2026-11-18.sqlite',
    );
  });

  test('cuts very long names without a dangling dash', () {
    final fileName = backupFileNameFor('${'a' * 39} bbbbbbbb', day);
    expect(fileName, 'Tinda360-${'a' * 39}-2026-11-18.sqlite');
    expect(fileName.length, lessThan(70));
  });

  test('pads single digit months and days', () {
    expect(
      backupFileNameFor('Sari', DateTime(2026, 1, 5)),
      'Tinda360-Sari-2026-01-05.sqlite',
    );
  });
}
