import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class FeedbackSharingTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final isSharing = ref.watch(feedbackConsentProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TindaListRow(
          title: localizations.settingsShareFeedbackTitle,
          subtitle: localizations.settingsShareFeedbackSubtitle,
          trailing: TindaToggleSwitch(
            value: isSharing,
            onChanged: (granted) {
              unawaited(HapticFeedback.selectionClick());
              unawaited(
                ref
                    .read(feedbackConsentProvider.notifier)
                    .setGranted(granted: granted),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s4,
          ),
          child: Text(
            localizations.settingsShareFeedbackDetails,
            style: AppTypography.meta(palette.textMuted),
          ),
        ),
      ],
    );
  }
}
