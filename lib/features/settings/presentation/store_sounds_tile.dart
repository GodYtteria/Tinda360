import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/services/store_sounds.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';

class StoreSoundsTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final setting = ref.watch(storeSoundsEnabledProvider);
    final isEnabled =
        setting.value ?? FileStoreSoundSettingStore.enabledByDefault;
    return TindaListRow(
      title: localizations.settingsStoreSoundsTitle,
      subtitle: localizations.settingsStoreSoundsSubtitle,
      trailing: IgnorePointer(
        ignoring: setting.isLoading,
        child: TindaToggleSwitch(
          value: isEnabled,
          onChanged: (enabled) {
            unawaited(HapticFeedback.selectionClick());
            unawaited(_applyChoice(ref, enabled: enabled));
          },
        ),
      ),
    );
  }

  Future<void> _applyChoice(WidgetRef ref, {required bool enabled}) async {
    final notifier = ref.read(storeSoundsEnabledProvider.notifier);
    final player = ref.read(storeSoundPlayerProvider);
    final log = ref.read(appLogProvider);
    try {
      await notifier.setEnabled(enabled: enabled);
    } on Object catch (error, stack) {
      log.error('sound.setting', error, stack);
      return;
    }
    if (enabled) player.play(StoreSound.addedToCart);
  }
}
