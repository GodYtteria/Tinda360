import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/services/receipt_print_service.dart';

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

String _receipt({
  required Money paid,
  required Money change,
  required String paymentLabel,
}) => ReceiptPrintService.buildReceiptText(
  storeName: 'Tindahan ni Aling Nena',
  lines: const ['Kape x2 sachet = ₱20.00'],
  total: _php(2000),
  paid: paid,
  change: change,
  paymentLabel: paymentLabel,
  timestamp: DateTime(2026, 11, 18, 9, 30),
  localizations: AppLocalizationsEn(),
);

void main() {
  test('utang receipt shows the utang amount, never Paid or Change', () {
    final text = _receipt(
      paid: _php(0),
      change: _php(0),
      paymentLabel: 'Utang',
    );
    expect(text, contains('Payment: Utang'));
    expect(text, contains('Utang: ₱20.00'));
    expect(text, isNot(contains('Paid:')));
    expect(text, isNot(contains('Change:')));
  });

  test('cash receipt shows Paid and Change, no utang line', () {
    final text = _receipt(
      paid: _php(5000),
      change: _php(3000),
      paymentLabel: 'Cash',
    );
    expect(text, contains('Payment: Cash'));
    expect(text, contains('Paid: ₱50.00'));
    expect(text, contains('Change: ₱30.00'));
    expect(text, isNot(contains('Utang:')));
  });

  test('partly paid receipt shows both Paid and the remaining utang', () {
    final text = _receipt(
      paid: _php(500),
      change: _php(0),
      paymentLabel: 'Utang',
    );
    expect(text, contains('Paid: ₱5.00'));
    expect(text, contains('Utang: ₱15.00'));
    expect(text, isNot(contains('Change:')));
  });

  test('details add receipt number, suki and reference rows', () {
    final text = ReceiptPrintService.buildReceiptText(
      storeName: 'Tindahan ni Aling Nena',
      lines: const ['Kape x2 sachet = ₱20.00'],
      total: _php(2000),
      paid: _php(500),
      change: _php(0),
      paymentLabel: 'Utang',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsEn(),
      details: const ReceiptDetails(
        receiptNumber: '20261118-003',
        customerName: 'Ate Maria',
        ewalletReference: 'GC-1234',
      ),
    );
    expect(text, contains('Receipt no.: 20261118-003'));
    expect(text, contains('Suki: Ate Maria'));
    expect(text, contains('Ref: GC-1234'));
    expect(text, contains('Paid: ₱5.00'));
    expect(text, contains('Utang: ₱15.00'));
  });

  test('receipt without details has no detail rows', () {
    final text = _receipt(
      paid: _php(2000),
      change: _php(0),
      paymentLabel: 'Cash',
    );
    expect(text, isNot(contains('Receipt no.')));
    expect(text, isNot(contains('Suki:')));
    expect(text, isNot(contains('Ref:')));
  });

  test('pdf with details builds', () async {
    final bytes = await ReceiptPrintService.build58mmReceiptPdf(
      storeName: 'Tindahan',
      lines: const ['Kape x2 sachet = ₱20.00'],
      total: _php(2000),
      paid: _php(500),
      change: _php(0),
      paymentLabel: 'Utang',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsEn(),
      details: const ReceiptDetails(
        receiptNumber: '20261118-003',
        customerName: 'Ate Maria',
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('empty item list still produces a receipt', () {
    final text = ReceiptPrintService.buildReceiptText(
      storeName: '',
      lines: const [],
      total: _php(0),
      paid: _php(0),
      change: _php(0),
      paymentLabel: 'Cash',
      timestamp: DateTime(2026, 11, 18),
      localizations: AppLocalizationsEn(),
    );
    expect(text, contains('Shop 360'));
    expect(text, isNot(contains('Tinda 360')));
    expect(text, contains('(No items)'));
  });

  test(
    'a receipt with no store name uses the Filipino app name in Filipino',
    () {
      final text = ReceiptPrintService.buildReceiptText(
        storeName: '',
        lines: const [],
        total: _php(0),
        paid: _php(0),
        change: _php(0),
        paymentLabel: 'Cash',
        timestamp: DateTime(2026, 11, 18),
        localizations: AppLocalizationsFil(),
      );
      expect(text, contains('Tinda 360'));
      expect(text, isNot(contains('Shop 360')));
    },
  );

  test('Filipino receipt uses Filipino labels', () {
    final text = ReceiptPrintService.buildReceiptText(
      storeName: 'Tindahan ni Aling Nena',
      lines: const ['Kape x2 sachet = ₱20.00'],
      total: _php(2000),
      paid: _php(5000),
      change: _php(3000),
      paymentLabel: 'Cash',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsFil(),
    );
    expect(text, contains('KABUUAN: ₱20.00'));
    expect(text, contains('Bayad: ₱50.00'));
    expect(text, contains('Sukli: ₱30.00'));
    expect(text, endsWith('Salamat po!'));
    expect(text, isNot(contains('Thank you')));
  });
}
