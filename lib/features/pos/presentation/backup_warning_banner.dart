import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/features/pos/data/backup_warning.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/backup_status.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class BackupWarningBanner extends ConsumerWidget {
  const BackupWarningBanner({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(backupWarningProvider).value ?? false)) {
      return const SizedBox.shrink();
    }
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final connectedBefore = ref.watch(backupWarningConnectedProvider).value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.s12),
      child: GestureDetector(
        onTap: onOpenSettings,
        child: TindaBanner(
          icon: Icons.cloud_off_outlined,
          title: connectedBefore ?? false
              ? localizations.posBackupStaleTitle
              : localizations.posBackupNeverTitle,
          body: localizations.posBackupWarningBody,
          trailing: IconButton(
            onPressed: () async {
              await ref
                  .read(backupStatusStoreProvider)
                  .writeWarningDismissedDay(
                    backupWarningDayKey(ref.read(clockProvider).now()),
                  );
              ref.invalidate(backupWarningProvider);
            },
            tooltip: localizations.commonClose,
            icon: Icon(Icons.close, size: 18, color: palette.onAccentSoft),
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTargetMin,
              minHeight: AppSizes.touchTargetMin,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
