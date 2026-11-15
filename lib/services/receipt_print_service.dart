import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

/// Builds and prints 58mm thermal receipts.
abstract final class ReceiptPrintService {
  static const String _dividerText = '--------------------------------';

  /// Generates a 58mm thermal roll PDF receipt.
  static Future<Uint8List> build58mmReceiptPdf({
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
  }) async {
    final document = pw.Document();
    final effectiveStoreName = storeName.trim().isEmpty
        ? 'Tinda 360'
        : _sanitizeAscii(storeName.trim());

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _buildHeader(
              storeName: effectiveStoreName,
              timestamp: timestamp,
            ),
            _buildDivider(),
            ..._buildLineItems(lines),
            _buildDivider(),
            _buildSummarySection(
              total: total,
              paid: paid,
              change: change,
              paymentLabel: paymentLabel,
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Thank you!',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    return await document.save();
  }

  /// Opens the system print dialog for a 58mm thermal receipt.
  static Future<void> print58mmReceipt({
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => build58mmReceiptPdf(
        storeName: storeName,
        lines: lines,
        total: total,
        paid: paid,
        change: change,
        paymentLabel: paymentLabel,
        timestamp: timestamp,
      ),
    );
  }

  static pw.Widget _buildHeader({
    required String storeName,
    required DateTime timestamp,
  }) => pw.Column(
    children: [
      pw.Text(
        storeName,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        _formatTimestamp(timestamp),
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8),
      ),
    ],
  );

  static pw.Widget _buildDivider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Text(
      _dividerText,
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 7),
    ),
  );

  static List<pw.Widget> _buildLineItems(List<String> lines) {
    if (lines.isEmpty) {
      return [
        pw.Text(
          '(No items)',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ];
    }
    return [
      for (final line in lines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            _sanitizeAscii(line),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
    ];
  }

  static pw.Widget _buildSummarySection({
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _buildSummaryRow(
        label: 'TOTAL',
        value: _formatPdfMoney(total),
        isBold: true,
      ),
      _buildSummaryRow(
        label: 'Payment',
        value: _sanitizeAscii(paymentLabel),
      ),
      _buildSummaryRow(
        label: 'Paid',
        value: _formatPdfMoney(paid),
      ),
      _buildSummaryRow(
        label: 'Change',
        value: _formatPdfMoney(change),
      ),
    ],
  );

  static pw.Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    final textStyle = pw.TextStyle(
      fontSize: isBold ? 9 : 8,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: textStyle),
          pw.Text(value, style: textStyle),
        ],
      ),
    );
  }

  static String _formatPdfMoney(Money money) =>
      _sanitizeAscii(formatMoney(money));

  static String _sanitizeAscii(String text) => text.replaceAll('₱', 'PHP ');

  static String _formatTimestamp(DateTime timestamp) {
    final localTimestamp = timestamp.toLocal();
    final year = localTimestamp.year.toString().padLeft(4, '0');
    final month = localTimestamp.month.toString().padLeft(2, '0');
    final day = localTimestamp.day.toString().padLeft(2, '0');
    final hour = localTimestamp.hour.toString().padLeft(2, '0');
    final minute = localTimestamp.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
