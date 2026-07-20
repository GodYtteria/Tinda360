import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Bottom sheet that shows a CSV data table preview with an export button.
class CsvPreviewSheet extends StatelessWidget {
  /// Creates a CSV preview sheet.
  const CsvPreviewSheet({
    required this.title,
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.csvContent,
    required this.successMessage,
    super.key,
  });

  /// Sheet title (e.g. "Export Products CSV").
  final String title;

  /// Column header names.
  final List<String> headers;

  /// Data rows. Each inner list must have the same length as [headers].
  final List<List<String>> rows;

  /// Suggested file name for the export.
  final String fileName;

  /// Raw CSV string to write when exporting.
  final String csvContent;

  /// Snackbar message shown after a successful export.
  final String successMessage;

  /// Maximum rows to display in the preview table.
  static const int _maxPreviewRows = 50;

  /// Opens this sheet as a modal bottom sheet.
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

  /// Normalizes a row to exactly [columnCount] cells, padding short rows
  /// with empty strings and truncating long ones.
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
              TindaBadge(label: localizations.csvPreviewRowCount(rows.length)),
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
                            for (final cell
                                in _normalizeRow(row, columnCount))
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
    if (savedPath == null) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }
}

/// Parses a CSV string into headers and rows for [CsvPreviewSheet].
({List<String> headers, List<List<String>> rows}) parseCsvForPreview(
  String csvContent,
) {
  final lines = const LineSplitter().convert(csvContent);
  if (lines.isEmpty) {
    return (headers: <String>[], rows: <List<String>>[]);
  }
  final headers = _parseCsvLine(lines.first);
  final rows = <List<String>>[];
  for (var index = 1; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    rows.add(_parseCsvLine(line));
  }
  return (headers: headers, rows: rows);
}

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current.write(char);
      }
    } else {
      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        fields.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
  }
  fields.add(current.toString());
  return fields;
}
