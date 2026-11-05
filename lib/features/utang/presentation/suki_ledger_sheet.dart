import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/interest_rate.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/features/utang/presentation/ledger_entry_delete.dart';
import 'package:tinda360/features/utang/presentation/suki_edit_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/features/utang/presentation/utang_balances_provider.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

final sukiLedgerProvider = StreamProvider.autoDispose
    .family<List<LedgerRecord>, String>(
      (ref, customerId) =>
          ref.watch(customerRepositoryProvider).watchLedger(customerId),
    );

final _ledgerStoreProfileProvider = StreamProvider.autoDispose<StoreProfile>(
  (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
);

String buildUtangReminderMessage({
  required AppLocalizations localizations,
  required String customerName,
  required String storeName,
  required String formattedBalance,
  String? formattedUtang,
  String? formattedInterest,
}) {
  final effectiveStoreName = storeName.trim().isEmpty
      ? localizations.ledgerReminderDefaultStore
      : storeName.trim();
  if (formattedUtang != null && formattedInterest != null) {
    return localizations.ledgerReminderTuboMessage(
      customerName,
      effectiveStoreName,
      formattedUtang,
      formattedInterest,
      formattedBalance,
    );
  }
  return localizations.ledgerReminderMessage(
    customerName,
    effectiveStoreName,
    formattedBalance,
  );
}

class SukiLedgerSheet extends ConsumerWidget {
  const SukiLedgerSheet({
    required this.balance,
    required this.onPay,
    super.key,
  });

  final CustomerBalance balance;

  final VoidCallback onPay;

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
    final current =
        ref
            .watch(utangBalancesProvider)
            .value
            ?.where((entry) => entry.customer.id == balance.customer.id)
            .firstOrNull ??
        balance;

    return TindaBottomSheet(
      title: current.customer.name,
      closeTooltip: localizations.commonClose,
      footer: Row(
        children: [
          Expanded(
            child: TindaSecondaryButton(
              label: localizations.ledgerShareReminder,
              icon: Icons.share_rounded,
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  _shareReminder(
                    context: context,
                    storeName: storeName,
                    current: current,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          IconButton(
            tooltip: localizations.ledgerCopyReminder,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(
                _copyReminder(
                  context: context,
                  storeName: storeName,
                  current: current,
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: TindaAccentButton(
              label: localizations.utangPayButton,
              onPressed: current.owes
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
          _LedgerBalanceSummary(balance: current),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s16,
            children: [
              if (current.canAddInterest)
                TindaTextLinkButton(
                  label: localizations.ledgerAddTubo,
                  onPressed: () =>
                      unawaited(_addInterest(context, ref, current)),
                ),
              TindaTextLinkButton(
                label: localizations.sukiEditAction,
                onPressed: () => unawaited(_editSuki(context, current)),
              ),
              TindaTextLinkButton(
                label: localizations.sukiDeleteAction,
                isDanger: true,
                onPressed: () => unawaited(_deleteSuki(context, ref, current)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            localizations.ledgerHistoryTitle,
            style: AppTypography.bodyStrong(palette.text, size: 15),
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildLedgerContent(
            context: context,
            ref: ref,
            localizations: localizations,
            palette: palette,
            ledgerAsync: ledgerAsync,
          ),
        ],
      ),
    );
  }

  Future<void> _editSuki(BuildContext context, CustomerBalance current) =>
      SukiEditSheet.show(context, current.customer);

  Future<void> _addInterest(
    BuildContext context,
    WidgetRef ref,
    CustomerBalance current,
  ) async {
    final localizations = AppLocalizations.of(context);
    final rateTenths = current.customer.interestPercentTenths;
    if (rateTenths == null) return;
    final expectedAmount = computeInterest(
      current.outstandingUtang,
      rateTenths,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.ledgerTuboConfirmTitle),
        content: Text(
          localizations.ledgerTuboConfirmBody(
            formatMoney(current.outstandingUtang),
            formatInterestPercent(rateTenths),
            formatMoney(expectedAmount),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.ledgerTuboConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final verified = await confirmStorePinIfSet(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified || !context.mounted) return;
    final result = await ref
        .read(customerRepositoryProvider)
        .addInterest(current.customer.id, expectedAmount);
    if (!context.mounted) return;
    final message = switch (result) {
      Ok(:final value) => localizations.ledgerTuboAdded(formatMoney(value)),
      Err(:final failure) => localizedFailureMessage(localizations, failure),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteSuki(
    BuildContext context,
    WidgetRef ref,
    CustomerBalance current,
  ) async {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.sukiDeleteConfirmTitle),
        content: Text(
          localizations.sukiDeleteConfirmBody(current.customer.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: Text(localizations.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final verified = await confirmStorePinIfSet(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified || !context.mounted) return;
    final result = await ref
        .read(customerRepositoryProvider)
        .softDelete(current.customer.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizedFailureMessage(localizations, failure)),
          ),
        );
    }
  }

  String _reminderText({
    required BuildContext context,
    required String storeName,
    required CustomerBalance current,
  }) => buildUtangReminderMessage(
    localizations: AppLocalizations.of(context),
    customerName: current.customer.name,
    storeName: storeName,
    formattedBalance: formatMoney(current.balance),
    formattedUtang: current.outstandingInterest.isPositive
        ? formatMoney(current.outstandingUtang)
        : null,
    formattedInterest: current.outstandingInterest.isPositive
        ? formatMoney(current.outstandingInterest)
        : null,
  );

  Future<void> _shareReminder({
    required BuildContext context,
    required String storeName,
    required CustomerBalance current,
  }) async {
    final text = _reminderText(
      context: context,
      storeName: storeName,
      current: current,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _copyReminder({
    required BuildContext context,
    required String storeName,
    required CustomerBalance current,
  }) async {
    final reminderMessage = _reminderText(
      context: context,
      storeName: storeName,
      current: current,
    );
    await Clipboard.setData(ClipboardData(text: reminderMessage));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).ledgerReminderCopied),
      ),
    );
  }

  Widget _buildLedgerContent({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations localizations,
    required AppPalette palette,
    required AsyncValue<List<LedgerRecord>> ledgerAsync,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget content;
    if (ledgerAsync.isLoading && !ledgerAsync.hasValue) {
      content = Padding(
        key: const ValueKey('ledger-loading'),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.s24,
        ),
        child: Center(
          child: CircularProgressIndicator(color: palette.primary),
        ),
      );
    } else if (ledgerAsync.hasError && !ledgerAsync.hasValue) {
      content = Padding(
        key: const ValueKey('ledger-error'),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.s16,
        ),
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
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.s20,
          ),
          child: Center(
            child: Text(
              localizations.ledgerEmptyEntries,
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
            final row = _LedgerRecordRow(
              record: records[index],
              onTap: () => handleLedgerRecordTap(context, ref, records[index]),
            );
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
          MoneyText(
            balance.balance,
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
  const _LedgerRecordRow({required this.record, required this.onTap});

  final LedgerRecord record;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final isIncrease = record.isDebt || record.isInterest;
    final isDeleted = record.isDeleted;
    final amountColor = isDeleted
        ? palette.textMuted
        : isIncrease
        ? palette.danger
        : palette.success;
    final amountPrefix = isIncrease ? '+' : '-';
    final kindLabel = ledgerKindLabel(localizations, record);
    final formattedTimestamp = formatLedgerTimestamp(
      context,
      record.createdAtMs,
    );
    final strike = isDeleted ? TextDecoration.lineThrough : null;
    final deleteReason = record.deleteReason;
    final deletedBy = record.deletedByName;
    final deletedNote = switch ((deletedBy, deleteReason)) {
      (null, null) => localizations.ledgerDeletedNoReason,
      (null, final String reason) => localizations.ledgerDeletedWithReason(
        reason,
      ),
      (final String name, null) => localizations.ledgerDeletedByNoReason(name),
      (final String name, final String reason) =>
        localizations.ledgerDeletedByWithReason(name, reason),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: TindaCard(
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
                    style: AppTypography.bodyStrong(
                      isDeleted ? palette.textMuted : palette.text,
                    ).copyWith(decoration: strike),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    formattedTimestamp,
                    style: AppTypography.meta(palette.textMuted),
                  ),
                  if (isDeleted) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      deletedNote,
                      style: AppTypography.meta(palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Flexible(
              child: MoneyText.text(
                '$amountPrefix${formatMoney(record.amount)}',
                alignment: AlignmentDirectional.centerEnd,
                style: AppTypography.bodyStrong(
                  amountColor,
                  size: 16,
                  weight: FontWeight.w700,
                ).copyWith(decoration: strike),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
