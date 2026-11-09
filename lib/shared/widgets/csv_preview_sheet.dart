import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class CsvPreviewSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.csvContent,
    required this.successMessage,
    super.key,
  });

  final String title;

  final List<String> headers;

  final List<List<String>> rows;

  final String fileName;

  final String csvContent;

  final String successMessage;

  static const int _maxPreviewRows = 50;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
    required String csvContent,
    required String successMessage,
  }) {
    final palette = AppPalette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: palette.scrim,
      builder: (_) => CsvPreviewSheet(
        title: title,
        headers: headers,
        rows: rows,
        fileName: fileName,
        csvContent: csvContent,
        successMessage: successMessage,
      ),
    );
  }

  static List<String> _normalizeRow(List<String> row, int columnCount) {
    if (row.length == columnCount) return row;
    if (row.length > columnCount) return row.sublist(0, columnCount);
    return [...row, for (var i = row.length; i < columnCount; i++) ''];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final truncated = rows.length > _maxPreviewRows;
    final displayRows = truncated ? rows.sublist(0, _maxPreviewRows) : rows;
    final columnCount = headers.length;

    return TindaBottomSheet(
      title: localizations.csvPreviewTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.csvPreviewExport,
        onPressed: () => unawaited(_export(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyStrong(palette.text),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: TindaBadge(
                  label: localizations.csvPreviewRowCount(rows.length),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (headers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
              child: Center(
                child: Text(
                  localizations.csvPreviewRowCount(0),
                  style: AppTypography.body(palette.textMuted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      palette.surfaceMuted,
                    ),
                    columnSpacing: AppSpacing.s16,
                    horizontalMargin: AppSpacing.s12,
                    columns: [
                      for (final header in headers)
                        DataColumn(
                          label: Text(
                            header,
                            style: AppTypography.meta(
                              palette.textMuted,
                              size: 12,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in displayRows)
                        DataRow(
                          cells: [
                            for (final cell in _normalizeRow(row, columnCount))
                              DataCell(
                                Text(
                                  cell,
                                  style: AppTypography.meta(
                                    palette.text,
                                    size: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (truncated) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              localizations.csvPreviewMoreRows(
                rows.length - _maxPreviewRows,
              ),
              style: AppTypography.meta(palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final savedPath = await FilePicker.saveFile(
      dialogTitle: title,
      fileName: fileName,
      bytes: utf8.encode(csvContent),
    );
    if (savedPath == null || !context.mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }
}

({List<String> headers, List<List<String>> rows}) parseCsvForPreview(
  String csvContent,
) {
  final parsedRows = const ProductCsvImporter()
      .parseCsvRows(csvContent)
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
  if (parsedRows.isEmpty) {
    return (headers: <String>[], rows: <List<String>>[]);
  }
  return (headers: parsedRows.first, rows: parsedRows.sublist(1));
}
