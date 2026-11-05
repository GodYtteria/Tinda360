import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

final class ReceiptDetails {
  const ReceiptDetails({
    this.receiptNumber,
    this.customerName,
    this.ewalletReference,
    this.interest,
    this.cashierName,
    this.storeAddress,
    this.storePhone,
    this.refunded,
  });

  final Money? interest;

  final Money? refunded;

  final String? cashierName;

  final String? storeAddress;

  final String? storePhone;

  ReceiptDetails withStoreContact({
    required String? address,
    required String? phone,
    required String? bantayName,
  }) => ReceiptDetails(
    receiptNumber: receiptNumber,
    customerName: customerName,
    ewalletReference: ewalletReference,
    interest: interest,
    refunded: refunded,
    cashierName: cashierName ?? bantayName,
    storeAddress: storeAddress ?? address,
    storePhone: storePhone ?? phone,
  );

  List<String> storeContactLines() {
    final address = ReceiptPrintService.sanitizeForReceiptFont(
      storeAddress ?? '',
    );
    final phone = ReceiptPrintService.sanitizeForReceiptFont(storePhone ?? '');
    return [if (address.isNotEmpty) address, if (phone.isNotEmpty) phone];
  }

  final String? receiptNumber;

  final String? customerName;

  final String? ewalletReference;

  List<(String, String)> labeledRows(AppLocalizations localizations) {
    final number = receiptNumber?.trim() ?? '';
    final customer = customerName?.trim() ?? '';
    final reference = ewalletReference?.trim() ?? '';
    final bantay = cashierName?.trim() ?? '';
    return [
      if (number.isNotEmpty) (localizations.receiptNumberLabel, number),
      if (bantay.isNotEmpty) (localizations.receiptBantayLabel, bantay),
      if (customer.isNotEmpty) (localizations.receiptSukiLabel, customer),
      if (reference.isNotEmpty)
        (localizations.receiptReferenceLabel, reference),
    ];
  }
}

abstract final class ReceiptPrintService {
  static const String _dividerText = '--------------------------------';

  static String buildReceiptText({
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
    required AppLocalizations localizations,
    ReceiptDetails details = const ReceiptDetails(),
  }) {
    final trimmedStoreName = storeName.trim();
    final buffer = StringBuffer()
      ..writeln(trimmedStoreName.isEmpty ? 'Tinda 360' : trimmedStoreName);
    details.storeContactLines().forEach(buffer.writeln);
    buffer.writeln(_formatTimestamp(timestamp));
    for (final (label, value) in details.labeledRows(localizations)) {
      buffer.writeln('$label: $value');
    }
    buffer.writeln(_dividerText);
    if (lines.isEmpty) {
      buffer.writeln(localizations.receiptNoItems);
    } else {
      lines.forEach(buffer.writeln);
    }
    buffer
      ..writeln(_dividerText)
      ..writeln('${localizations.receiptTotal}: ${formatMoney(total)}')
      ..writeln('${localizations.receiptPayment}: $paymentLabel');
    for (final (label, amount) in settlementRows(
      total: total,
      paid: paid,
      change: change,
      interest: details.interest,
      refunded: details.refunded,
      localizations: localizations,
    )) {
      buffer.writeln('$label: ${formatMoney(amount)}');
    }
    buffer
      ..writeln()
      ..write(localizations.receiptThankYou);
    return buffer.toString();
  }

  static Future<Uint8List> build58mmReceiptPdf({
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
    required AppLocalizations localizations,
    ReceiptDetails details = const ReceiptDetails(),
  }) async {
    final document = pw.Document();
    final printableStoreName = sanitizeForReceiptFont(storeName);
    final effectiveStoreName = printableStoreName.isEmpty
        ? 'Tinda 360'
        : printableStoreName;

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
              contactLines: details.storeContactLines(),
              timestamp: timestamp,
              detailRows: details.labeledRows(localizations),
            ),
            _buildDivider(),
            ..._buildLineItems(lines, localizations),
            _buildDivider(),
            _buildSummarySection(
              total: total,
              paid: paid,
              change: change,
              paymentLabel: paymentLabel,
              interest: details.interest,
              refunded: details.refunded,
              localizations: localizations,
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                sanitizeForReceiptFont(localizations.receiptThankYou),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    return await document.save();
  }

  static Future<void> print58mmReceipt({
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
    required AppLocalizations localizations,
    ReceiptDetails details = const ReceiptDetails(),
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
        localizations: localizations,
        details: details,
      ),
    );
  }

  static pw.Widget _buildHeader({
    required String storeName,
    required List<String> contactLines,
    required DateTime timestamp,
    required List<(String, String)> detailRows,
  }) => pw.Column(
    children: [
      pw.Text(
        storeName.toUpperCase(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      pw.SizedBox(height: 2),
      for (final contactLine in contactLines)
        pw.Text(
          contactLine,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8),
        ),
      pw.Text(
        _formatTimestamp(timestamp),
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8),
      ),
      for (final (label, value) in detailRows)
        pw.Text(
          sanitizeForReceiptFont('$label: $value'),
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

  static List<pw.Widget> _buildLineItems(
    List<String> lines,
    AppLocalizations localizations,
  ) {
    if (lines.isEmpty) {
      return [
        pw.Text(
          sanitizeForReceiptFont(localizations.receiptNoItems),
          style: const pw.TextStyle(fontSize: 8),
        ),
      ];
    }
    return [
      for (final line in lines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            sanitizeForReceiptFont(line),
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
    required Money? interest,
    required Money? refunded,
    required AppLocalizations localizations,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _buildSummaryRow(
        label: sanitizeForReceiptFont(localizations.receiptTotal),
        value: _formatPdfMoney(total),
        isBold: true,
      ),
      _buildSummaryRow(
        label: sanitizeForReceiptFont(localizations.receiptPayment),
        value: sanitizeForReceiptFont(paymentLabel),
      ),
      for (final (label, amount) in settlementRows(
        total: total,
        paid: paid,
        change: change,
        interest: interest,
        refunded: refunded,
        localizations: localizations,
      ))
        _buildSummaryRow(
          label: sanitizeForReceiptFont(label),
          value: _formatPdfMoney(amount),
        ),
    ],
  );

  static List<(String, Money)> settlementRows({
    required Money total,
    required Money paid,
    required Money change,
    required Money? interest,
    required AppLocalizations localizations,
    Money? refunded,
  }) {
    final rows = <(String, Money)>[];
    if (paid < total) {
      final interestAmount = interest ?? Money.zero(total.currency);
      if (paid.isPositive) rows.add((localizations.receiptPaid, paid));
      rows.add((localizations.receiptUtang, total - paid + interestAmount));
      if (interestAmount.isPositive) {
        rows.add((localizations.receiptInterest, interestAmount));
      }
    } else {
      rows
        ..add((localizations.receiptPaid, paid))
        ..add((localizations.receiptChange, change));
    }
    if (refunded != null && refunded.isPositive) {
      rows
        ..add((localizations.receiptRefunded, refunded))
        ..add((localizations.receiptNetTotal, total - refunded));
    }
    return rows;
  }

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
      sanitizeForReceiptFont(formatMoney(money));

  static const Map<String, String> _plainPunctuationBySmartPunctuation = {
    '₱': 'PHP ',
    '\u2018': "'",
    '\u2019': "'",
    '\u201C': '"',
    '\u201D': '"',
    '\u2013': '-',
    '\u2014': '-',
    '\u2026': '...',
    '\u00A0': ' ',
  };

  static const int _lastLatin1CodePoint = 0xFF;

  static String sanitizeForReceiptFont(String text) {
    final plainText = StringBuffer();
    for (final codePoint in text.runes) {
      final character = String.fromCharCode(codePoint);
      final replacement = _plainPunctuationBySmartPunctuation[character];
      if (replacement != null) {
        plainText.write(replacement);
      } else if (codePoint <= _lastLatin1CodePoint) {
        plainText.write(character);
      }
    }
    return plainText.toString().replaceAll(RegExp(' {2,}'), ' ').trim();
  }

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
