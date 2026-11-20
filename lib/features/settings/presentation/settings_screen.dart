import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/database_maintenance.dart';
import 'package:tinda360/data/db/store_registry.dart';
import 'package:tinda360/features/pos/presentation/bantay_chip.dart';
import 'package:tinda360/features/settings/presentation/feedback_sharing_tile.dart';
import 'package:tinda360/features/settings/presentation/optional_text_dialog.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/routing/app_router.dart';
import 'package:tinda360/services/backup_file_name.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/pin_prompt_dialog.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

part 'settings_store_section.dart';

class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final settingsState = ref.watch(settingsNotifierProvider);
    final storeProfileAsync = ref.watch(storeProfileStreamProvider);
    final storeProfile = storeProfileAsync.value;
    final storeName = storeProfile?.name ?? '';
    final bantayName = ref.watch(bantayNameProvider).value;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          TindaHeaderBar(
            leading: TindaIconButton(
              icon: Icons.arrow_back,
              tooltip: localizations.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              onHeader: true,
            ),
            title: Text(localizations.settingsTitle),
          ),
          Expanded(
            child: TindaScreenBody(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.s20,
                  AppSpacing.screenHorizontal,
                  AppSpacing.s24,
                ),
                children: [
                  _SectionHeader(title: localizations.settingsSectionBackup),
                  const SizedBox(height: AppSpacing.s10),
                  _BackupSection(state: settingsState),
                  const SizedBox(height: AppSpacing.s20),
                  _SectionHeader(title: localizations.settingsSectionAi),
                  const SizedBox(height: AppSpacing.s10),
                  _AiSection(),
                  const SizedBox(height: AppSpacing.s10),
                  const FeedbackSharingTile(),
                  const SizedBox(height: AppSpacing.s20),
                  _SectionHeader(title: localizations.settingsSectionStore),
                  const SizedBox(height: AppSpacing.s10),
                  TindaListRow(
                    title: localizations.onboardingStoreNameLabel,
                    subtitle: storeName.isEmpty ? '—' : storeName,
                    onTap: () => unawaited(
                      _renameStore(context, ref, storeName),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  TindaListRow(
                    title: localizations.receiptBantayLabel,
                    subtitle: bantayName ?? '—',
                    onTap: () => unawaited(
                      editBantayName(context, ref, bantayName),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  TindaListRow(
                    title: localizations.settingsAddressLabel,
                    subtitle: storeProfile?.address ?? '—',
                    onTap: () => unawaited(
                      _editStoreContact(
                        context,
                        ref,
                        profile: storeProfile,
                        isAddress: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  TindaListRow(
                    title: localizations.settingsPhoneLabel,
                    subtitle: storeProfile?.phone ?? '—',
                    onTap: () => unawaited(
                      _editStoreContact(
                        context,
                        ref,
                        profile: storeProfile,
                        isAddress: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  TindaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localizations.settingsLanguageLabel,
                          style: AppTypography.bodyStrong(palette.text),
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        TindaSegmentedControl<String>(
                          segments: {
                            'en': localizations.settingsLanguageEn,
                            'fil': localizations.settingsLanguagePh,
                          },
                          selected: ref.watch(localeProvider).languageCode,
                          onChanged: (code) {
                            if (code == ref.read(localeProvider).languageCode) {
                              return;
                            }
                            unawaited(HapticFeedback.selectionClick());
                            ref
                                .read(localeProvider.notifier)
                                .setLanguageCode(code);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  _StoreSwitcherSection(activeStoreName: storeName),
                  const SizedBox(height: AppSpacing.s20),
                  _SectionHeader(title: localizations.settingsSectionStorage),
                  const SizedBox(height: AppSpacing.s10),
                  _StorageSection(
                    isBackupConnected:
                        settingsState.backupStatus == BackupStatus.connected,
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  _SectionHeader(title: localizations.settingsSectionPrivacy),
                  const SizedBox(height: AppSpacing.s10),
                  _PrivacySection(),
                  const SizedBox(height: AppSpacing.s20),
                  _SectionHeader(title: localizations.settingsSectionAbout),
                  const SizedBox(height: AppSpacing.s10),
                  TindaListRow(
                    title: localizations.appTitle,
                    subtitle: localizations.settingsVersion,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTypography.section(AppPalette.of(context).textMuted),
  );
}

class _BackupSection extends ConsumerWidget {
  const new({required this.state});

  final SettingsState state;

  Future<void> _disconnectBackupWithPin(
    BuildContext context,
    WidgetRef ref,
    SettingsNotifier notifier,
  ) async {
    final title = AppLocalizations.of(context).settingsPinPromptTitle;
    final pinVerified = await confirmStorePinIfSet(context, ref, title: title);
    if (!pinVerified) return;
    await notifier.disconnectBackup();
  }

  String _backupErrorLabel(
    AppLocalizations localizations,
    String reason,
  ) {
    final isFilipino = localizations.localeName.startsWith('fil');
    return switch (reason) {
      'no_backup_found' =>
        isFilipino
            ? 'Walang nahanap na backup sa Google Drive.'
            : 'No backup found in Google Drive.',
      'not_signed_in' =>
        isFilipino
            ? 'Hindi naka-sign in sa Google.'
            : 'Not signed in to Google.',
      'authorization_denied' =>
        isFilipino
            ? 'Hindi pinayagan ang access sa Google Drive.'
            : 'Google Drive access was not granted.',
      'missing_local_database' =>
        isFilipino
            ? 'Walang lokal na database na ma-upload.'
            : 'No local database found to upload.',
      'invalid_media_response' || 'invalid_backup_file' =>
        isFilipino
            ? 'Hindi mabasa ang backup file mula sa Drive.'
            : 'Could not read backup file from Drive.',
      _ =>
        isFilipino
            ? 'Hindi natapos ang backup. Tingnan ang internet at subukan ulit.'
            : 'Backup did not finish. Check your internet and try again.',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final statusLabel = switch (state.backupStatus) {
      BackupStatus.notConnected => localizations.settingsBackupNotConnected,
      BackupStatus.connecting => localizations.settingsBackupConnecting,
      BackupStatus.choosing => localizations.settingsBackupConnected,
      BackupStatus.connected => localizations.settingsBackupConnected,
      BackupStatus.failed => localizations.settingsBackupNotConnected,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TindaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TindaStatusDot(
                    active:
                        state.backupStatus == BackupStatus.connected ||
                        state.backupStatus == BackupStatus.choosing,
                    color:
                        state.backupStatus == BackupStatus.connected ||
                            state.backupStatus == BackupStatus.choosing
                        ? palette.success
                        : (state.backupStatus == BackupStatus.failed
                              ? palette.danger
                              : palette.textMuted),
                    size: 10,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 180,
                      ),
                      child: Text(
                        state.accountEmail ?? statusLabel,
                        key: ValueKey<String>(
                          '${state.backupStatus.name}:${state.accountEmail ?? ''}',
                        ),
                        style: AppTypography.bodyStrong(palette.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              AnimatedSwitcher(
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 220,
                ),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(state.backupStatus),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.backupStatus == BackupStatus.choosing) ...[
                        Text(
                          localizations.settingsBackupChooseTitle,
                          style: AppTypography.body(palette.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TindaPrimaryButton(
                          label: localizations.settingsBackupUsePhone,
                          onPressed: () {
                            unawaited(HapticFeedback.selectionClick());
                            unawaited(notifier.choosePhoneData());
                          },
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        TindaSecondaryButton(
                          label: localizations.settingsBackupRestore,
                          onPressed: () {
                            unawaited(HapticFeedback.mediumImpact());
                            unawaited(notifier.chooseRestoreBackup());
                          },
                        ),
                      ] else if (state.backupStatus ==
                          BackupStatus.connected) ...[
                        if (state.syncedJustNow) ...[
                          Text(
                            localizations.settingsBackupLastSync(
                              localizations.settingsBackupJustNow,
                            ),
                            style: AppTypography.meta(
                              palette.textMuted,
                              size: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                        ],
                        TindaSecondaryButton(
                          label: localizations.settingsBackupSyncNow,
                          onPressed: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(notifier.syncNow());
                          },
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Center(
                          child: TindaTextLinkButton(
                            label: localizations.settingsBackupDisconnect,
                            isDanger: true,
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              unawaited(
                                _disconnectBackupWithPin(
                                  context,
                                  ref,
                                  notifier,
                                ),
                              );
                            },
                          ),
                        ),
                      ] else
                        TindaGoogleButton(
                          label: localizations.onboardingGoogleButton,
                          onPressed:
                              state.backupStatus == BackupStatus.connecting
                              ? null
                              : () {
                                  unawaited(HapticFeedback.mediumImpact());
                                  unawaited(notifier.connectBackup());
                                },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.backupStatus == BackupStatus.connected) ...[
          const SizedBox(height: AppSpacing.s10),
          TindaListRow(
            title: localizations.settingsAutoBackup,
            subtitle: localizations.settingsBackupWifiOnly,
            trailing: TindaToggleSwitch(
              value: state.autoBackupEnabled,
              onChanged: (value) {
                unawaited(HapticFeedback.selectionClick());
                notifier.toggleAutoBackup(value);
              },
            ),
          ),
        ],
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
          ),
          child: state.backupStatus == BackupStatus.failed
              ? Padding(
                  key: const ValueKey('backup-failed'),
                  padding: const EdgeInsets.only(top: AppSpacing.s10),
                  child: TindaCard(
                    backgroundColor: palette.dangerSoft,
                    borderColor: palette.danger.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localizations.settingsBackupFailed,
                          style: AppTypography.body(palette.danger),
                        ),
                        if (state.errorReason != null &&
                            state.errorReason!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            _backupErrorLabel(
                              localizations,
                              state.errorReason!,
                            ),
                            style: AppTypography.meta(palette.danger),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s12),
                        TindaSecondaryButton(
                          label: localizations.commonRetry,
                          onPressed: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(notifier.retryBackup());
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('backup-ok')),
        ),
      ],
    );
  }
}

class _AiSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return TindaCard(
      child: Row(
        children: [
          const TindaAiAvatar(size: 36),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.chatTitle,
                  style: AppTypography.bodyStrong(palette.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                TindaBadge(label: localizations.settingsAiOfflineBadge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final promises = [
      localizations.settingsPrivacyTracking,
      localizations.settingsPrivacyOfflineAi,
      localizations.settingsPrivacyDataSafety,
    ];
    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < promises.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.s10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: palette.primary,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    promises[index],
                    style: AppTypography.body(palette.text),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageSection extends ConsumerStatefulWidget {
  const new({required this.isBackupConnected});

  final bool isBackupConnected;

  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
  bool _isCompacting = false;

  Future<void> _compactNow() async {
    if (_isCompacting) return;
    setState(() => _isCompacting = true);
    try {
      final database = ref.read(appDatabaseProvider);
      await compactDatabase(database);
      final file = await ref.read(databaseFileProvider)();
      final newBytes = measureDatabaseBytes(file);
      ref.invalidate(databaseSizeBytesProvider);
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations.settingsCompactDone(formatByteCount(newBytes)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCompacting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final sizeAsync = ref.watch(databaseSizeBytesProvider);
    final sizeLabel = sizeAsync.when(
      data: formatByteCount,
      loading: () => '…',
      error: (_, _) => '—',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isBackupConnected) ...[
          TindaBanner(
            icon: Icons.warning_amber_rounded,
            title: localizations.settingsNoBackupWarningTitle,
            body: localizations.settingsNoBackupWarningBody,
          ),
          const SizedBox(height: AppSpacing.s10),
        ],
        TindaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      localizations.settingsStorageSizeLabel,
                      style: AppTypography.bodyStrong(palette.text),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 180,
                      ),
                      child: Text(
                        sizeLabel,
                        key: ValueKey<String>(sizeLabel),
                        textAlign: TextAlign.end,
                        style: AppTypography.meta(
                          palette.primary,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              TindaSecondaryButton(
                label: localizations.settingsCompactButton,
                onPressed: _isCompacting
                    ? null
                    : () {
                        unawaited(HapticFeedback.lightImpact());
                        unawaited(_compactNow());
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s10),
        TindaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations.settingsLocalBackupTitle,
                style: AppTypography.bodyStrong(palette.text),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                localizations.settingsLocalBackupSubtitle,
                style: AppTypography.meta(palette.textMuted, size: 13),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  Expanded(
                    child: TindaSecondaryButton(
                      label: localizations.settingsLocalExportButton,
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        unawaited(_exportLocalBackup(context, ref));
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: TindaSecondaryButton(
                      label: localizations.settingsLocalImportButton,
                      onPressed: () {
                        unawaited(HapticFeedback.mediumImpact());
                        unawaited(_importLocalBackup(context, ref));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s10),
        const _PinLockSection(),
      ],
    );
  }

  Future<void> _exportLocalBackup(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(localBackupServiceProvider);
      final database = ref.read(appDatabaseProvider);
      final databaseFile = await ref.read(databaseFileProvider)();
      final bytes = await service.exportDatabaseBytes(
        database: database,
        databaseFile: databaseFile,
      );
      final storeProfile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      final savedPath = await FilePicker.saveFile(
        dialogTitle: localizations.settingsLocalExportButton,
        fileName: backupFileNameFor(storeProfile.name, DateTime.now()),
        bytes: bytes,
      );
      if (savedPath == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsLocalExportSuccess)),
      );
    } on Exception catch (error, stack) {
      ref.read(appLogProvider).error('settings.local_backup', error, stack);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsLocalBackupFailed)),
      );
    }
  }

  Future<void> _importLocalBackup(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = ref.read(appRouterProvider);
    final log = ref.read(appLogProvider);
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsLocalImportConfirmTitle),
        content: Text(localizations.settingsLocalImportConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.settingsLocalImportButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pinVerified = await confirmStorePinIfSet(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!pinVerified) return;

    final pickedFiles = await FilePicker.pickFiles();
    final pickedPath = pickedFiles.firstOrNull?.path;
    if (pickedPath == null) return;

    try {
      final service = container.read(localBackupServiceProvider);
      final database = container.read(appDatabaseProvider);
      final targetFile = await container.read(databaseFileProvider)();
      await service.importDatabaseFile(
        sourceFile: File(pickedPath),
        keepSourceFile: true,
        targetFile: targetFile,
        closeActiveDatabase: () async {
          await leaveScreensReadingDatabase(router);
          await database.close();
        },
        invalidateDatabase: () {
          container
            ..invalidate(appDatabaseProvider)
            ..invalidate(ulatNotifierProvider);
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsLocalImportSuccess)),
      );
    } on FormatException {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsLocalImportInvalid)),
      );
    } on Exception catch (error, stack) {
      log.error('settings.local_backup', error, stack);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsLocalBackupFailed)),
      );
    }
  }
}

class _PinLockSection extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PinLockSection> createState() => _PinLockSectionState();
}

class _PinLockSectionState extends ConsumerState<_PinLockSection> {
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPinState());
  }

  Future<void> _refreshPinState() async {
    final enabled = await ref.read(storePinServiceProvider).hasPin();
    if (!mounted) return;
    setState(() => _hasPin = enabled);
  }

  Future<void> _setPin() async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pinService = ref.read(storePinServiceProvider);
    if (_hasPin) {
      final verified = await verifyStorePin(
        context,
        ref,
        title: localizations.settingsPinPromptTitle,
      );
      if (!verified || !mounted) return;
    }
    final newPin = await showSetPinDialog(
      context,
      title: localizations.settingsPinSetButton,
    );
    if (newPin == null) return;
    final recoveryCode = await pinService.setPin(newPin);
    await _refreshPinState();
    if (mounted) {
      await showRecoveryCodeDialog(context, recoveryCode: recoveryCode);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.settingsPinSetSuccess)),
    );
  }

  Future<void> _removePin() async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pinService = ref.read(storePinServiceProvider);
    final verified = await verifyStorePin(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified) return;
    await pinService.clearPin();
    await _refreshPinState();
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.settingsPinRemoved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.settingsPinTitle,
            style: AppTypography.bodyStrong(palette.text),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _hasPin
                ? localizations.settingsPinSubtitleOn
                : localizations.settingsPinSubtitleOff,
            style: AppTypography.meta(palette.textMuted, size: 13),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: TindaSecondaryButton(
                  label: localizations.settingsPinSetButton,
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(_setPin());
                  },
                ),
              ),
              if (_hasPin) ...[
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: TindaTextLinkButton(
                    label: localizations.settingsPinRemoveButton,
                    isDanger: true,
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(_removePin());
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
