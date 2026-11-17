import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Live ledger entries for a single suki ordered newest first.
final sukiLedgerProvider = StreamProvider.autoDispose
    .family<List<LedgerRecord>, String>(
      (ref, customerId) =>
          ref.watch(customerRepositoryProvider).watchLedger(customerId),
    );

final _ledgerStoreProfileProvider = StreamProvider.autoDispose<StoreProfile>(
  (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
);

/// Builds a polite Filipino/English utang reminder message for [customerName].
String buildUtangReminderMessage({
  required String customerName,
  required String storeName,
  required String formattedBalance,
}) {
  final effectiveStoreName = storeName.trim().isEmpty
      ? 'our store'
      : storeName.trim();
  return 'Magandang araw, $customerName! Friendly reminder po from '
      '$effectiveStoreName regarding your utang balance of '
      '$formattedBalance. Salamat po!';
}

/// Bottom sheet showing a suki's utang ledger history, reminder copy, and pay action.
class SukiLedgerSheet extends ConsumerWidget {
  /// Creates the suki ledger sheet.
  const SukiLedgerSheet({
    required this.balance,
    required this.onPay,
    super.key,
  });

  /// Selected suki and current balance.
  final CustomerBalance balance;

  /// Callback invoked when the user taps Pay.
  final VoidCallback onPay;

  /// Presents the ledger sheet for [balance].
  static Future<void> show(
    BuildContext context, {
    required CustomerBalance balance,
    required VoidCallback onPay,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) => SukiLedgerSheet(balance: balance, onPay: onPay),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ledgerAsync = ref.watch(sukiLedgerProvider(balance.customer.id));
    final storeProfileAsync = ref.watch(_ledgerStoreProfileProvider);
    final storeName = storeProfileAsync.value?.name ?? '';

    return TindaBottomSheet(
      title: balance.customer.name,
      closeTooltip: localizations.commonClose,
      footer: Row(
        children: [
          Expanded(
            child: TindaSecondaryButton(
              label: 'Copy Reminder',
              icon: Icons.copy_rounded,
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  _copyReminder(
                    context: context,
                    storeName: storeName,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: TindaAccentButton(
              label: localizations.utangPayButton,
              onPressed: balance.owes
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      onPay();
                    }
                  : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LedgerBalanceSummary(balance: balance),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Ledger History',
            style: AppTypography.bodyStrong(palette.text, size: 15),
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildLedgerContent(
            context: context,
            localizations: localizations,
            palette: palette,
            ledgerAsync: ledgerAsync,
          ),
        ],
      ),
    );
  }

  Future<void> _copyReminder({
    required BuildContext context,
    required String storeName,
  }) async {
    final reminderMessage = buildUtangReminderMessage(
      customerName: balance.customer.name,
      storeName: storeName,
      formattedBalance: formatMoney(balance.balance),
    );
    await Clipboard.setData(ClipboardData(text: reminderMessage));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder copied to clipboard')),
    );
  }

  Widget _buildLedgerContent({
    required BuildContext context,
    required AppLocalizations localizations,
    required AppPalette palette,
    required AsyncValue<List<LedgerRecord>> ledgerAsync,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget content;
    if (ledgerAsync.isLoading && !ledgerAsync.hasValue) {
      content = Padding(
        key: const ValueKey('ledger-loading'),
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.s24),
        child: Center(
          child: CircularProgressIndicator(color: palette.primary),
        ),
      );
    } else if (ledgerAsync.hasError && !ledgerAsync.hasValue) {
      content = Padding(
        key: const ValueKey('ledger-error'),
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.s16),
        child: Text(
          localizations.homeLoadFailed,
          style: AppTypography.body(palette.danger),
        ),
      );
    } else {
      final records = ledgerAsync.value ?? const <LedgerRecord>[];
      if (records.isEmpty) {
        content = Padding(
          key: const ValueKey('ledger-empty'),
          padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.s20),
          child: Center(
            child: Text(
              'No ledger entries yet.',
              style: AppTypography.meta(palette.textMuted),
            ),
          ),
        );
      } else {
        content = ListView.separated(
          key: ValueKey('ledger-${records.length}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
          itemBuilder: (context, index) {
            final row = _LedgerRecordRow(record: records[index]);
            if (reduceMotion) return row;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 150 + (index.clamp(0, 8) * 20)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 6),
                  child: child,
                ),
              ),
              child: row,
            );
          },
        );
      }
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: content,
    );
  }
}

class _LedgerBalanceSummary extends StatelessWidget {
  const _LedgerBalanceSummary({required this.balance});

  final CustomerBalance balance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizations.utangCurrentBalance,
            style: AppTypography.meta(palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            formatMoney(balance.balance),
            style: AppTypography.display(
              balance.owes ? palette.danger : palette.text,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRecordRow extends StatelessWidget {
  const _LedgerRecordRow({required this.record});

  final LedgerRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDebt = record.isDebt;
    final amountColor = isDebt ? palette.danger : palette.success;
    final amountPrefix = isDebt ? '+' : '-';
    final kindLabel = isDebt ? 'Utang' : 'Payment';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      record.createdAtMs,
    ).toLocal();
    final formattedTimestamp = DateFormat('MMM d, y · h:mm a').format(timestamp);

    return TindaCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kindLabel,
                  style: AppTypography.bodyStrong(palette.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  formattedTimestamp,
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(
            '$amountPrefix${formatMoney(record.amount)}',
            style: AppTypography.bodyStrong(
              amountColor,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
