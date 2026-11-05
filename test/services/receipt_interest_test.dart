import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/services/receipt_print_service.dart';

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

String _receipt({
  required AppLocalizations localizations,
  required Money paid,
  Money? interest,
}) => ReceiptPrintService.buildReceiptText(
  storeName: 'Tindahan ni Aling Nena',
  lines: const ['Kape x2 sachet = ₱100.00'],
  total: _php(10000),
  paid: paid,
  change: _php(0),
  paymentLabel: 'Utang',
  timestamp: DateTime(2026, 11, 18, 9, 30),
  localizations: localizations,
  details: ReceiptDetails(interest: interest),
);

void main() {
  test('english receipt shows utang plus interest and an Interest row', () {
    final text = _receipt(
      localizations: AppLocalizationsEn(),
      paid: _php(0),
      interest: _php(1000),
    );
    expect(text, contains('TOTAL: ₱100.00'));
    expect(text, contains('Utang: ₱110.00'));
    expect(text, contains('Interest: ₱10.00'));
    expect(text, isNot(contains('Paid:')));
  });

  test('filipino receipt uses Interes', () {
    final text = _receipt(
      localizations: AppLocalizationsFil(),
      paid: _php(0),
      interest: _php(1000),
    );
    expect(text, contains('Interes: ₱10.00'));
    expect(text, contains('Utang: ₱110.00'));
  });

  test('partly paid receipt keeps Paid and adds interest to the rest', () {
    final text = _receipt(
      localizations: AppLocalizationsEn(),
      paid: _php(4000),
      interest: _php(600),
    );
    expect(text, contains('Paid: ₱40.00'));
    expect(text, contains('Utang: ₱66.00'));
    expect(text, contains('Interest: ₱6.00'));
  });

  test('receipt without interest has no interest row', () {
    for (final localizations in [AppLocalizationsEn(), AppLocalizationsFil()]) {
      final text = _receipt(localizations: localizations, paid: _php(0));
      expect(text, contains('Utang: ₱100.00'));
      expect(text, isNot(contains('Interest')));
      expect(text, isNot(contains('Interes:')));
    }
  });

  test('zero interest adds no row', () {
    final text = _receipt(
      localizations: AppLocalizationsEn(),
      paid: _php(0),
      interest: _php(0),
    );
    expect(text, isNot(contains('Interest')));
  });

  test('pdf builds with interest rows', () async {
    final bytes = await ReceiptPrintService.build58mmReceiptPdf(
      storeName: 'Tindahan',
      lines: const ['Kape x2 sachet = ₱100.00'],
      total: _php(10000),
      paid: _php(0),
      change: _php(0),
      paymentLabel: 'Utang',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsFil(),
      details: ReceiptDetails(interest: _php(1000)),
    );
    expect(bytes, isNotEmpty);
  });
}
