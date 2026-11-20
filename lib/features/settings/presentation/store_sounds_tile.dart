import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/store_sounds.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';

class StoreSoundsTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final isEnabled =
        ref.watch(storeSoundsEnabledProvider).value ??
        FileStoreSoundSettingStore.enabledByDefault;
    return TindaListRow(
      title: localizations.settingsStoreSoundsTitle,
      subtitle: localizations.settingsStoreSoundsSubtitle,
      trailing: TindaToggleSwitch(
        value: isEnabled,
        onChanged: (enabled) {
          unawaited(HapticFeedback.selectionClick());
          unawaited(
            ref
                .read(storeSoundsEnabledProvider.notifier)
                .setEnabled(enabled: enabled),
          );
          if (enabled) {
            ref.read(storeSoundPlayerProvider).play(StoreSound.addedToCart);
          }
        },
      ),
    );
  }
}
