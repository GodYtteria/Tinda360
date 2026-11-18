import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/services/receipt_print_service.dart';

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

String _receipt(
  AppLocalizations localizations, {
  ReceiptDetails details = const ReceiptDetails(),
}) => ReceiptPrintService.buildReceiptText(
  storeName: 'Tindahan ni Nena',
  lines: const ['Kape x2 = ₱20.00'],
  total: _php(2000),
  paid: _php(2000),
  change: _php(0),
  paymentLabel: 'Cash',
  timestamp: DateTime(2026, 11, 18, 9, 30),
  localizations: localizations,
  details: details,
);

void main() {
  for (final localizations in [AppLocalizationsEn(), AppLocalizationsFil()]) {
    final language = localizations.localeName;
    final label = language == 'en' ? 'On duty' : 'Bantay';

    test('$language: bantay line printed only when set', () {
      final withBantay = _receipt(
        localizations,
        details: const ReceiptDetails(cashierName: ' Ana '),
      );
      expect(withBantay, contains('$label: Ana'));
      expect(_receipt(localizations), isNot(contains(label)));
      expect(
        _receipt(
          localizations,
          details: const ReceiptDetails(cashierName: '  '),
        ),
        isNot(contains(label)),
      );
    });

    test('$language: address and phone sit under the store name', () {
      final lines = _receipt(
        localizations,
        details: const ReceiptDetails(
          storeAddress: '12 Rizal St, Cebu',
          storePhone: '0917 123 4567',
        ),
      ).split('\n');
      expect(lines[0], 'Tindahan ni Nena');
      expect(lines[1], '12 Rizal St, Cebu');
      expect(lines[2], '0917 123 4567');
      expect(lines[3], '2026-11-18 09:30');
    });

    test('$language: no address or phone lines when unset', () {
      final lines = _receipt(localizations).split('\n');
      expect(lines[1], '2026-11-18 09:30');
    });
  }

  test('address and phone are sanitized for the receipt font', () {
    const details = ReceiptDetails(
      storeAddress: 'Brgy “San Jose” 中',
      storePhone: '  ',
    );
    expect(details.storeContactLines(), ['Brgy "San Jose"']);
  });

  test('withStoreContact keeps explicit values over the defaults', () {
    const details = ReceiptDetails(cashierName: 'Ana', storeAddress: 'A');
    final merged = details.withStoreContact(
      address: 'B',
      phone: '123',
      bantayName: 'Ben',
    );
    expect(merged.cashierName, 'Ana');
    expect(merged.storeAddress, 'A');
    expect(merged.storePhone, '123');
  });

  test('58mm pdf builds with address, phone and bantay', () async {
    final bytes = await ReceiptPrintService.build58mmReceiptPdf(
      storeName: 'Tindahan ni Nena',
      lines: const ['Kape x2 = 20'],
      total: _php(2000),
      paid: _php(2000),
      change: _php(0),
      paymentLabel: 'Cash',
      timestamp: DateTime(2026, 11, 18, 9, 30),
      localizations: AppLocalizationsEn(),
      details: const ReceiptDetails(
        cashierName: 'Ana',
        storeAddress: '12 Rizal St',
        storePhone: '0917',
      ),
    );
    expect(bytes, isNotEmpty);
  });
}
