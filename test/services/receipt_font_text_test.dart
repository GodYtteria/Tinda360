import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/services/receipt_print_service.dart';

void main() {
  test('keeps Filipino letters and fractions the receipt font can draw', () {
    expect(
      ReceiptPrintService.sanitizeForReceiptFont('Tindahan ni Aling Ñeneng'),
      'Tindahan ni Aling Ñeneng',
    );
    expect(
      ReceiptPrintService.sanitizeForReceiptFont('Bigas x2 ½ kilo = ₱100.00'),
      'Bigas x2 ½ kilo = PHP 100.00',
    );
  });

  test('turns smart punctuation into plain text', () {
    expect(
      ReceiptPrintService.sanitizeForReceiptFont(
        '“Special” Pandesal — 10 pcs…',
      ),
      '"Special" Pandesal - 10 pcs...',
    );
    expect(ReceiptPrintService.sanitizeForReceiptFont('It’s ok'), "It's ok");
  });

  test('drops emoji and scripts the receipt font cannot draw', () {
    expect(
      ReceiptPrintService.sanitizeForReceiptFont('Sari-Sari 🏪 Store'),
      'Sari-Sari Store',
    );
    expect(
      ReceiptPrintService.sanitizeForReceiptFont('👨‍👩‍👧 鸡蛋 Itlog'),
      'Itlog',
    );
    expect(ReceiptPrintService.sanitizeForReceiptFont('🍞🍞'), '');
  });
}
