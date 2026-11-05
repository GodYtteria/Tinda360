import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/features/settings/presentation/optional_text_dialog.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

Future<void> editBantayName(
  BuildContext context,
  WidgetRef ref,
  String? currentName,
) async {
  final localizations = AppLocalizations.of(context);
  final edited = await showOptionalTextDialog(
    context,
    title: localizations.bantayDialogTitle,
    label: localizations.receiptBantayLabel,
    hintText: localizations.bantayFieldHint,
    initialText: currentName ?? '',
  );
  if (edited == null) return;
  await ref.read(bantayNameProvider.notifier).setName(edited);
}

class BantayChip extends ConsumerWidget {
  const BantayChip({super.key});

  static const double _maxChipWidth = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final name = ref.watch(bantayNameProvider).value;
    final label = name == null
        ? localizations.bantayChipEmpty
        : localizations.bantayChipLabel(name);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.smallButton),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(editBantayName(context, ref, name));
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _maxChipWidth,
            minHeight: 48,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta(palette.onHeader),
            ),
          ),
        ),
      ),
    );
  }
}
