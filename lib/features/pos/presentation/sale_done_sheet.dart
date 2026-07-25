import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Confirmation sheet shown after a sale is recorded.
class SaleDoneSheet extends StatefulWidget {
  /// Creates the sale-done sheet.
  const SaleDoneSheet({
    required this.total,
    required this.paid,
    required this.change,
    required this.receiptLines,
    required this.storeName,
    required this.timestamp,
    super.key,
  });

  /// Total sale amount.
  final Money total;

  /// Amount paid at the counter (equals [total] for e-wallet/utang).
  final Money paid;

  /// Change due, computed via `SaleMath.changeDue`.
  final Money change;

  /// Formatted line summaries included when sharing the receipt.
  final List<String> receiptLines;

  /// Store name shown on the shared/printed receipt.
  final String storeName;

  /// Time the sale was recorded.
  final DateTime timestamp;

  @override
  State<SaleDoneSheet> createState() => _SaleDoneSheetState();
}

class _SaleDoneSheetState extends State<SaleDoneSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(_playSaleCelebrationFeedback());
  }

  Future<void> _playSaleCelebrationFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } on Exception {
      return;
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final storeLabel = widget.storeName.trim().isEmpty
        ? localizations.appTitle
        : widget.storeName.trim();
    final buffer = StringBuffer()
      ..writeln(storeLabel.toUpperCase())
      ..writeln(_formatReceiptTimestamp(widget.timestamp))
      ..writeln('------------------------------');
    for (final line in widget.receiptLines) {
      buffer.writeln(line);
    }
    buffer
      ..writeln('------------------------------')
      ..writeln('${localizations.saleDoneTotal}: ${formatMoney(widget.total)}')
      ..writeln('${localizations.saleDonePaid}: ${formatMoney(widget.paid)}')
      ..writeln('${localizations.saleDoneChange}: ${formatMoney(widget.change)}');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.saleDoneReceiptCopied)),
    );
  }

  String _formatReceiptTimestamp(DateTime timestamp) {
    final localTimestamp = timestamp.toLocal();
    final year = localTimestamp.year.toString().padLeft(4, '0');
    final month = localTimestamp.month.toString().padLeft(2, '0');
    final day = localTimestamp.day.toString().padLeft(2, '0');
    final hour = localTimestamp.hour.toString().padLeft(2, '0');
    final minute = localTimestamp.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheetTop),
        ),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.borderStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: const TindaAiAvatar(
                  mood: TindaAvatarMood.happy,
                  size: 120,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                localizations.saleDoneTitle,
                textAlign: TextAlign.center,
                style: AppTypography.title(palette.text),
              ),
              const SizedBox(height: AppSpacing.s20),
              _AmountsSummaryCard(
                total: widget.total,
                paid: widget.paid,
                change: widget.change,
              ),
              const SizedBox(height: AppSpacing.s24),
              TindaPrimaryButton(
                label: localizations.saleDoneNewSale,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpacing.s12),
              TindaSecondaryButton(
                label: localizations.saleDoneShareReceipt,
                icon: Icons.share_outlined,
                onPressed: () => _shareReceipt(context),
              ),
              const SizedBox(height: AppSpacing.s10),
              TindaSecondaryButton(
                label: localizations.receiptPrint58mm,
                icon: Icons.print_outlined,
                onPressed: () => unawaited(
                  ReceiptPreviewSheet.show(
                    context,
                    storeName: widget.storeName.trim().isEmpty
                        ? localizations.appTitle
                        : widget.storeName,
                    lines: widget.receiptLines,
                    total: widget.total,
                    paid: widget.paid,
                    change: widget.change,
                    paymentLabel: localizations.saleDonePaid,
                    timestamp: widget.timestamp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountsSummaryCard extends StatelessWidget {
  const _AmountsSummaryCard({
    required this.total,
    required this.paid,
    required this.change,
  });

  final Money total;
  final Money paid;
  final Money change;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return TindaCard(
      backgroundColor: palette.surfaceMuted,
      child: Column(
        children: [
          _SummaryRow(
            label: localizations.saleDoneTotal,
            value: formatMoney(total),
          ),
          const SizedBox(height: AppSpacing.s8),
          _SummaryRow(
            label: localizations.saleDonePaid,
            value: formatMoney(paid),
          ),
          Divider(height: AppSpacing.s24, color: palette.borderStrong),
          Text(
            localizations.saleDoneChange,
            style: AppTypography.meta(palette.textMuted, size: 13),
          ),
          const SizedBox(height: AppSpacing.s4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, _) => Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.9 + 0.1 * value,
                child: Text(
                  formatMoney(change),
                  style: AppTypography.display(palette.success, size: 34),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body(palette.textMuted)),
        Text(value, style: AppTypography.bodyStrong(palette.text)),
      ],
    );
  }
}
