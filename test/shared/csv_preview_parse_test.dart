import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';

void main() {
  test('keeps a quoted name with a line break inside one row', () {
    final parsed = parseCsvForPreview(
      'name,price\r\n"Kape\nBarako",12.00\r\nAsukal,60.00\r\n',
    );

    expect(parsed.headers, ['name', 'price']);
    expect(parsed.rows, [
      ['Kape\nBarako', '12.00'],
      ['Asukal', '60.00'],
    ]);
  });

  test('returns empty headers and rows for empty or blank input', () {
    expect(parseCsvForPreview('').headers, isEmpty);
    expect(parseCsvForPreview('  \n \n').rows, isEmpty);
  });

  test('keeps unicode names and quoted commas', () {
    final parsed = parseCsvForPreview('name,price\n"Piña, malaki",45.50\n');
    expect(parsed.rows.single, ['Piña, malaki', '45.50']);
  });
}
