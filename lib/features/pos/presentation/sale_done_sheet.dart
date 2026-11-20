import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/services/receipt_print_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/services/store_sounds.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class SaleDoneSheet extends ConsumerStatefulWidget {
  const new({
    required this.total,
    required this.paid,
    required this.change,
    required this.receiptLines,
    required this.paymentMethod,
    required this.storeName,
    required this.timestamp,
    this.details = const ReceiptDetails(),
    super.key,
  });

  final Money total;

  final Money paid;

  final Money change;

  final List<String> receiptLines;

  final PaymentMethod paymentMethod;

  final String storeName;

  final DateTime timestamp;

  final ReceiptDetails details;

  @override
  ConsumerState<SaleDoneSheet> createState() => _SaleDoneSheetState();
}

class _SaleDoneSheetState extends ConsumerState<SaleDoneSheet> {
  ReceiptDetails _detailsWithStoreContact() {
    final storeProfile = ref.read(storeProfileStreamProvider).value;
    return widget.details.withStoreContact(
      address: storeProfile?.address,
      phone: storeProfile?.phone,
      bantayName: ref.read(bantayNameProvider).value,
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_playSaleCelebrationFeedback());
  }

  Future<void> _playSaleCelebrationFeedback() async {
    ref.read(storeSoundPlayerProvider).play(StoreSound.saleComplete);
    final log = ref.read(appLogProvider);
    try {
      await HapticFeedback.mediumImpact();
    } on Exception catch (error, stack) {
      log.error('sale.haptic', error, stack);
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final storeLabel = widget.storeName.trim().isEmpty
        ? localizations.appTitle
        : widget.storeName.trim();
    final text = ReceiptPrintService.buildReceiptText(
      storeName: storeLabel,
      lines: widget.receiptLines,
      total: widget.total,
      paid: widget.paid,
      change: widget.change,
      paymentLabel: localizedPaymentMethod(
        localizations,
        widget.paymentMethod,
      ),
      timestamp: widget.timestamp,
      localizations: localizations,
      details: _detailsWithStoreContact(),
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: storeLabel),
      );
    } on Exception catch (error, stack) {
      debugPrint('receipt.share failed: $error\n$stack');
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(localizations.saleDoneShareFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);

    return ResponsiveSheetBody(
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
            interest:
                widget.details.interest ?? Money.zero(widget.total.currency),
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
            onPressed: () => unawaited(_shareReceipt(context)),
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
                paymentLabel: localizedPaymentMethod(
                  localizations,
                  widget.paymentMethod,
                ),
                timestamp: widget.timestamp,
                details: _detailsWithStoreContact(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountsSummaryCard extends StatelessWidget {
  const new({
    required this.total,
    required this.paid,
    required this.change,
    required this.interest,
  });

  final Money total;
  final Money paid;
  final Money change;
  final Money interest;

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
          if (paid < total) ...[
            if (paid.isPositive) ...[
              _SummaryRow(
                label: localizations.saleDonePaid,
                value: formatMoney(paid),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            _SummaryRow(
              label: localizations.checkoutMethodUtang,
              value: formatMoney(total - paid + interest),
            ),
            if (interest.isPositive) ...[
              const SizedBox(height: AppSpacing.s8),
              _SummaryRow(
                label: localizations.receiptInterest,
                value: formatMoney(interest),
              ),
            ],
          ] else ...[
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
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(palette.textMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: MoneyText.text(
            value,
            alignment: AlignmentDirectional.centerEnd,
            style: AppTypography.bodyStrong(palette.text),
          ),
        ),
      ],
    );
  }
}
