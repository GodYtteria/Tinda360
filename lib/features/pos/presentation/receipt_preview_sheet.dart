import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/receipt_print_service.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';

/// Bottom sheet that shows a 58mm receipt PDF preview with a print button.
class ReceiptPreviewSheet extends StatelessWidget {
  /// Creates a receipt preview sheet.
  const ReceiptPreviewSheet({
    required this.storeName,
    required this.lines,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentLabel,
    required this.timestamp,
    super.key,
  });

  /// Store name printed on the receipt header.
  final String storeName;

  /// Formatted line summaries for the receipt body.
  final List<String> lines;

  /// Total sale amount.
  final Money total;

  /// Amount paid.
  final Money paid;

  /// Change due.
  final Money change;

  /// Label for the payment method row.
  final String paymentLabel;

  /// Sale timestamp.
  final DateTime timestamp;

  /// Opens this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
  }) {
    final palette = AppPalette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: palette.scrim,
      builder: (_) => ReceiptPreviewSheet(
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return TindaBottomSheet(
      title: localizations.receiptPreviewTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.receiptPreviewPrint,
        onPressed: () {
          unawaited(HapticFeedback.mediumImpact());
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          unawaited(
            () async {
              try {
                await ReceiptPrintService.print58mmReceipt(
                  storeName: storeName,
                  lines: lines,
                  total: total,
                  paid: paid,
                  change: change,
                  paymentLabel: paymentLabel,
                  timestamp: timestamp,
                );
                navigator.pop();
              } on Exception {
                unawaited(HapticFeedback.heavyImpact());
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.localeName.startsWith('fil')
                          ? 'Hindi mabuksan ang print dialog.'
                          : 'Could not open print dialog.',
                    ),
                  ),
                );
              }
            }(),
          );
        },
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: child,
        ),
        child: SizedBox(
          height: 400,
          child: PdfPreview(
          build: (_) => ReceiptPrintService.build58mmReceiptPdf(
            storeName: storeName,
            lines: lines,
            total: total,
            paid: paid,
            change: change,
            paymentLabel: paymentLabel,
            timestamp: timestamp,
          ),
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          padding: EdgeInsets.zero,
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
