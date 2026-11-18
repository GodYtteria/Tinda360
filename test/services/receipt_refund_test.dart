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
  Money? refunded,
}) => ReceiptPrintService.buildReceiptText(
  storeName: 'Tindahan ni Aling Nena',
  lines: const ['Kape x2 sachet = ₱100.00'],
  total: _php(10000),
  paid: _php(10000),
  change: _php(0),
  paymentLabel: 'Cash',
  timestamp: DateTime(2026, 11, 18, 9, 30),
  localizations: localizations,
  details: ReceiptDetails(refunded: refunded),
);

void main() {
  test('english receipt shows Refunded and Net total rows after a return', () {
    final text = _receipt(
      localizations: AppLocalizationsEn(),
      refunded: _php(4000),
    );
    expect(text, contains('TOTAL: ₱100.00'));
    expect(text, contains('Refunded: ₱40.00'));
    expect(text, contains('Net total: ₱60.00'));
  });

  test('filipino receipt labels the refund rows in Filipino', () {
    final text = _receipt(
      localizations: AppLocalizationsFil(),
      refunded: _php(4000),
    );
    expect(text, contains('Naibalik: ₱40.00'));
    expect(text, contains('Netong kabuuan: ₱60.00'));
  });

  test('receipt without a refund has no refund rows', () {
    final withoutRefund = _receipt(localizations: AppLocalizationsEn());
    final withZeroRefund = _receipt(
      localizations: AppLocalizationsEn(),
      refunded: _php(0),
    );
    expect(withoutRefund, isNot(contains('Refunded')));
    expect(withZeroRefund, isNot(contains('Net total')));
  });

  test('refund rows follow a utang receipt too', () {
    final text = ReceiptPrintService.buildReceiptText(
      storeName: 'Tindahan ni Aling Nena',
      lines: const ['Kape x2 sachet = ₱100.00'],
      total: _php(10000),
      paid: _php(2000),
      change: _php(0),
      paymentLabel: 'Utang',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsEn(),
      details: ReceiptDetails(refunded: _php(3000)),
    );
    expect(text, contains('Utang: ₱80.00'));
    expect(text, contains('Refunded: ₱30.00'));
    expect(text, contains('Net total: ₱70.00'));
  });
}
