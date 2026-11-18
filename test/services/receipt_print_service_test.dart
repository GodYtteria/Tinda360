import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/services/receipt_print_service.dart';

void main() {
  test('build58mmReceiptPdf produces valid PDF bytes', () async {
    final pdfBytes = await ReceiptPrintService.build58mmReceiptPdf(
      storeName: 'Tindahan ni Aling Nena',
      lines: const [
        '2x Lucky Me Pancit Canton  PHP 36.00',
        '1x Silver Swan Soy Sauce   PHP 15.00',
      ],
      total: const Money(5100, Currency.php),
      paid: const Money(10000, Currency.php),
      change: const Money(4900, Currency.php),
      paymentLabel: 'Cash',
      timestamp: DateTime(2026, 11, 17, 14, 30),
      localizations: AppLocalizationsEn(),
    );

    expect(pdfBytes, isNotEmpty);
    expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');
  });

  test('build58mmReceiptPdf handles empty store name and peso signs', () async {
    final pdfBytes = await ReceiptPrintService.build58mmReceiptPdf(
      storeName: '',
      lines: const ['1x Coke Mismo  ₱20.00'],
      total: const Money(2000, Currency.php),
      paid: const Money(2000, Currency.php),
      change: const Money.zero(Currency.php),
      paymentLabel: 'GCash',
      timestamp: DateTime(2026, 11, 17, 9, 5),
      localizations: AppLocalizationsEn(),
    );

    expect(pdfBytes, isNotEmpty);
    expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');
  });
}
