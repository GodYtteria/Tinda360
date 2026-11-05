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

export 'package:tinda360/services/receipt_print_service.dart'
    show ReceiptDetails;

class ReceiptPreviewSheet extends StatelessWidget {
  const ReceiptPreviewSheet({
    required this.storeName,
    required this.lines,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentLabel,
    required this.timestamp,
    this.details = const ReceiptDetails(),
    super.key,
  });

  final String storeName;

  final List<String> lines;

  final Money total;

  final Money paid;

  final Money change;

  final String paymentLabel;

  final DateTime timestamp;

  final ReceiptDetails details;

  static Future<void> show(
    BuildContext context, {
    required String storeName,
    required List<String> lines,
    required Money total,
    required Money paid,
    required Money change,
    required String paymentLabel,
    required DateTime timestamp,
    ReceiptDetails details = const ReceiptDetails(),
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
        details: details,
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
                  localizations: localizations,
                  details: details,
                );
                if (context.mounted) navigator.pop();
              } on Exception {
                unawaited(HapticFeedback.heavyImpact());
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.receiptPrintDialogFailed,
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
              localizations: localizations,
              details: details,
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
