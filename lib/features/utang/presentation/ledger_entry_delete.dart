import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

enum LedgerTapAction { confirmDelete, showSaleHint, nothing }

bool isLedgerEntryDeletable(LedgerRecord record) => record.isDeletable;

LedgerTapAction ledgerTapActionFor(LedgerRecord record) {
  if (record.isDeleted) return LedgerTapAction.nothing;
  if (record.isDeletable) return LedgerTapAction.confirmDelete;
  return LedgerTapAction.showSaleHint;
}

String ledgerKindLabel(AppLocalizations localizations, LedgerRecord record) =>
    record.isInterest
    ? localizations.ledgerKindTubo
    : record.isDebt
    ? localizations.ledgerKindUtang
    : localizations.ledgerKindPayment;

String formatLedgerTimestamp(BuildContext context, int createdAtMs) =>
    DateFormat(
      'MMM d, y · h:mm a',
      Localizations.localeOf(context).toString(),
    ).format(DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal());

void handleLedgerRecordTap(
  BuildContext context,
  WidgetRef ref,
  LedgerRecord record,
) {
  switch (ledgerTapActionFor(record)) {
    case LedgerTapAction.confirmDelete:
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => LedgerEntryDeleteDialog(record: record, ref: ref),
        ),
      );
    case LedgerTapAction.showSaleHint:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).ledgerNotDeletableHint),
        ),
      );
    case LedgerTapAction.nothing:
      break;
  }
}

class LedgerEntryDeleteDialog extends StatefulWidget {
  const LedgerEntryDeleteDialog({
    required this.record,
    required this.ref,
    super.key,
  });

  final LedgerRecord record;

  final WidgetRef ref;

  @override
  State<LedgerEntryDeleteDialog> createState() =>
      _LedgerEntryDeleteDialogState();
}

class _LedgerEntryDeleteDialogState extends State<LedgerEntryDeleteDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isRunning = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isRunning) return;
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isRunning = true);
    final verified = await confirmStorePinIfSet(
      context,
      widget.ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified) {
      if (mounted) setState(() => _isRunning = false);
      return;
    }
    final result = await widget.ref
        .read(customerRepositoryProvider)
        .deleteLedgerEntry(
          widget.record.id,
          reason: _reasonController.text,
          deletedByName: widget.ref.read(bantayNameProvider).value,
        );
    final message = switch (result) {
      Ok() => localizations.ledgerDeleteDone,
      Err(:final failure) => localizedFailureMessage(localizations, failure),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (!mounted) return;
    if (result is Ok) {
      navigator.pop();
    } else {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final record = widget.record;
    return AlertDialog(
      title: Text(localizations.ledgerDeleteConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.ledgerDeleteConfirmBody(
              ledgerKindLabel(localizations, record),
              formatMoney(record.amount),
              formatLedgerTimestamp(context, record.createdAtMs),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _reasonController,
            enabled: !_isRunning,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: localizations.ledgerDeleteReasonLabel,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRunning ? null : () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: _isRunning ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: palette.danger),
          child: Text(localizations.ledgerDeleteConfirmAction),
        ),
      ],
    );
  }
}
