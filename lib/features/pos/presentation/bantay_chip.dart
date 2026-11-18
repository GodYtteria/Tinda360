import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
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
  const new({super.key});

  static const double _maxChipWidth = 140;
  static const double _chipHeight = 32;

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
            minHeight: AppSizes.touchTargetMin,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _chipHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.onHeader.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.smallButton),
                  border: Border.all(
                    color: palette.onHeader.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s4,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta(palette.onHeader),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
