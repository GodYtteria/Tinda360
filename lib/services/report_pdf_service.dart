import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

abstract final class ReportPdfService {
  static const String _logoAssetPath = 'assets/app_icon/app_icon_full.png';
  static final PdfColor _headerColor = PdfColor.fromHex('#0F5C4A');
  static final PdfColor _borderColor = PdfColor.fromHex('#D5DDD9');
  static final PdfColor _mutedTextColor = PdfColor.fromHex('#5A6863');
  static final PdfColor _stripeColor = PdfColor.fromHex('#F4F7F6');

  static Future<Uint8List> buildReportPdf({
    required String storeName,
    required String periodLabel,
    required UlatState state,
    required AppLocalizations localizations,
    required Money totalExpenses,
    Uint8List? logoBytes,
  }) async {
    final resolvedLogoBytes = await _loadLogoBytes(logoBytes);
    final document = pw.Document();
    final effectiveStoreName = storeName.trim().isEmpty
        ? 'Tinda 360'
        : storeName.trim();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(
            storeName: effectiveStoreName,
            periodLabel: periodLabel,
            range: state.range,
            logoBytes: resolvedLogoBytes,
          ),
          pw.SizedBox(height: 20),
          _buildSectionTitle(localizations.reportsTitle),
          pw.SizedBox(height: 8),
          _buildSummaryTable(
            state: state,
            localizations: localizations,
            totalExpenses: totalExpenses,
          ),
          pw.SizedBox(height: 20),
          _buildSectionTitle(localizations.reportsTopProductsTitle),
          pw.SizedBox(height: 8),
          _buildTopProductsTable(
            state: state,
            periodLabel: periodLabel,
            localizations: localizations,
          ),
          pw.SizedBox(height: 40),
          _buildSignatureSection(
            storeName: effectiveStoreName,
            localizations: localizations,
          ),
        ],
      ),
    );

    return await document.save();
  }

  static Future<Uint8List?> _loadLogoBytes(Uint8List? logoBytes) async {
    if (logoBytes != null) {
      return logoBytes;
    }
    try {
      final data = await rootBundle.load(_logoAssetPath);
      return data.buffer.asUint8List();
    } on Exception {
      return null;
    }
  }

  static pw.Widget _buildHeader({
    required String storeName,
    required String periodLabel,
    required DayRange range,
    required Uint8List? logoBytes,
  }) {
    final logoImage = logoBytes != null && logoBytes.isNotEmpty
        ? pw.MemoryImage(logoBytes)
        : null;

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _headerColor, width: 2),
        ),
      ),
      child: pw.Row(
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, width: 40, height: 40),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Tinda 360',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _headerColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  storeName,
                  style: const pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                periodLabel,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _headerColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${_formatLocalDay(range.first)} to '
                '${_formatLocalDay(range.last)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _mutedTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) => pw.Text(
    title,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _headerColor,
    ),
  );

  static pw.Widget _buildSummaryTable({
    required UlatState state,
    required AppLocalizations localizations,
    required Money totalExpenses,
  }) {
    final summary = state.summary;
    final rows = <List<String>>[
      [localizations.reportsSalesCard, _formatPdfMoney(summary.revenue)],
      [localizations.reportsProfitCard, _formatPdfMoney(summary.profit)],
      [localizations.reportsTransactionsCard, '${summary.saleCount}'],
      [localizations.reportsNewUtangCard, _formatPdfMoney(state.totalUtang)],
      [localizations.ulatExpensesTitle, _formatPdfMoney(totalExpenses)],
      [
        localizations.ulatNetIncomeLabel,
        _formatPdfMoney(summary.profit - totalExpenses),
      ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: [
        localizations.reportPdfMetricHeader,
        localizations.reportPdfValueHeader,
      ],
      data: rows,
      headerStyle: const pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _headerColor),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      border: pw.TableBorder.all(color: _borderColor, width: 0.75),
      oddRowDecoration: pw.BoxDecoration(color: _stripeColor),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildTopProductsTable({
    required UlatState state,
    required String periodLabel,
    required AppLocalizations localizations,
  }) {
    final rows = state.topProducts.isEmpty
        ? <List<String>>[
            [
              '-',
              localizations.reportsEmptyTitlePeriod(periodLabel),
              '-',
              '-',
            ],
          ]
        : [
            for (var index = 0; index < state.topProducts.length; index++)
              [
                '${index + 1}',
                state.topProducts[index].productName,
                formatQuantity(
                  state.topProducts[index].totalQuantity,
                  state.topProducts[index].unit,
                ),
                _formatPdfMoney(state.topProducts[index].totalRevenue),
              ],
          ];

    return pw.TableHelper.fromTextArray(
      headers: [
        '#',
        localizations.reportPdfProductHeader,
        localizations.reportPdfQuantitySoldHeader,
        localizations.reportPdfRevenueHeader,
      ],
      data: rows,
      headerStyle: const pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _headerColor),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      border: pw.TableBorder.all(color: _borderColor, width: 0.75),
      oddRowDecoration: pw.BoxDecoration(color: _stripeColor),
      cellAlignments: const {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FixedColumnWidth(32),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildSignatureSection({
    required String storeName,
    required AppLocalizations localizations,
  }) => pw.Center(
    child: pw.Column(
      children: [
        pw.Text(
          '______________________________',
          style: pw.TextStyle(
            fontSize: 11,
            color: _mutedTextColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          localizations.reportPdfPreparedBy(storeName),
          style: pw.TextStyle(
            fontSize: 10,
            color: _mutedTextColor,
          ),
        ),
      ],
    ),
  );

  static String _formatPdfMoney(Money money) =>
      formatMoney(money).replaceAll('₱', 'PHP ');

  static String _formatLocalDay(LocalDay day) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      day.serial * Duration.millisecondsPerDay,
      isUtc: true,
    );
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final dayOfMonth = date.day.toString().padLeft(2, '0');
    return '$year-$month-$dayOfMonth';
  }
}
