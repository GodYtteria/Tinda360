import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/database_maintenance.dart';
import 'package:tinda360/routing/app_router.dart';
import 'package:tinda360/services/backup_status.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/pin_prompt_dialog.dart';

enum BackupStatus {
  notConnected,

  connecting,

  choosing,

  connected,

  failed,
}

final class SettingsState {
  const new({
    required this.backupStatus,
    required this.autoBackupEnabled,
    this.accountEmail,
    this.syncedJustNow = false,
    this.errorReason,
  });

  final BackupStatus backupStatus;

  final bool autoBackupEnabled;

  final String? accountEmail;

  final bool syncedJustNow;

  final String? errorReason;

  SettingsState copyWith({
    BackupStatus? backupStatus,
    bool? autoBackupEnabled,
    String? accountEmail,
    bool? syncedJustNow,
    String? errorReason,
    bool clearError = false,
  }) => SettingsState(
    backupStatus: backupStatus ?? this.backupStatus,
    autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    accountEmail: accountEmail ?? this.accountEmail,
    syncedJustNow: syncedJustNow ?? this.syncedJustNow,
    errorReason: clearError ? null : (errorReason ?? this.errorReason),
  );
}

final StreamProvider<StoreProfile> storeProfileStreamProvider =
    StreamProvider.autoDispose<StoreProfile>(
      (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
    );

void _savePreferenceInBackground(Ref ref, Future<void> pendingWrite) {
  final appLog = ref.read(appLogProvider);
  unawaited(
    pendingWrite.catchError((Object error, StackTrace stack) {
      appLog.error('settings.save_preference', error, stack);
    }),
  );
}

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(
      SettingsNotifier.new,
    );

final FutureProvider<int> databaseSizeBytesProvider =
    FutureProvider.autoDispose<int>((ref) async {
      ref.watch(appDatabaseProvider);
      final file = await ref.watch(databaseFileProvider)();
      return measureDatabaseBytes(file);
    });

Future<int> compactStoreDatabase(Ref ref) async {
  final database = ref.read(appDatabaseProvider);
  await compactDatabase(database);
  final file = await ref.read(databaseFileProvider)();
  ref.invalidate(databaseSizeBytesProvider);
  return measureDatabaseBytes(file);
}

Future<void> _uploadQueue = Future<void>.value();

Future<BackupSyncResult> uploadStoreDatabase(
  Ref ref, {
  bool allowPrompt = false,
}) {
  final upload = _uploadQueue.then(
    (_) => _uploadStoreDatabaseNow(ref, allowPrompt: allowPrompt),
  );
  _uploadQueue = upload.then<void>(
    (_) {},
    onError: (Object error) => debugPrint('drive upload failed: $error'),
  );
  return upload;
}

Future<BackupSyncResult> _uploadStoreDatabaseNow(
  Ref ref, {
  required bool allowPrompt,
}) async {
  final database = ref.read(appDatabaseProvider);
  final storeId =
      ref.read(storeRegistryProvider).value?.activeStoreId ?? 'default';
  final file = await ref.read(databaseFileProvider)();
  final snapshotFile = File('${file.path}.snapshot');
  try {
    await createCompactedBackupSnapshot(database, snapshotFile);
    if (!snapshotFile.existsSync()) {
      return const BackupSyncFailed(reason: 'backup_snapshot_missing');
    }
    final uploadResult = await ref
        .read(driveBackupServiceProvider)
        .uploadDatabase(
          snapshotFile,
          storeId: storeId,
          accountEmail: await ref
              .read(backupPreferencesProvider)
              .readConnectedEmail(),
          allowPrompt: allowPrompt,
        );
    if (uploadResult is BackupSyncSuccess) {
      try {
        await ref
            .read(backupStatusStoreProvider)
            .writeLastSuccessfulBackup(ref.read(clockProvider).now());
      } on Object catch (error, stack) {
        ref.read(appLogProvider).error('backup.status', error, stack);
      }
    }
    return uploadResult;
  } on Exception catch (error, stack) {
    ref.read(appLogProvider).error('backup.upload', error, stack);
    return const BackupSyncFailed(reason: 'backup_snapshot_failed');
  } finally {
    if (snapshotFile.existsSync()) {
      snapshotFile.deleteSync();
    }
  }
}

Future<BackupSyncResult> restoreStoreDatabase(
  Ref ref, {
  bool allowPrompt = false,
}) async {
  final file = await ref.read(databaseFileProvider)();
  final downloadedFile = File('${file.path}.downloaded');
  final storeId =
      ref.read(storeRegistryProvider).value?.activeStoreId ?? 'default';
  try {
    final result = await ref
        .read(driveBackupServiceProvider)
        .downloadDatabaseTo(
          downloadedFile,
          storeId: storeId,
          accountEmail: await ref
              .read(backupPreferencesProvider)
              .readConnectedEmail(),
          allowPrompt: allowPrompt,
        );
    if (result is! BackupSyncSuccess) return result;
    try {
      await ref
          .read(localBackupServiceProvider)
          .importDatabaseFile(
            sourceFile: downloadedFile,
            keepSourceFile: false,
            targetFile: file,
            closeActiveDatabase: () async {
              await leaveScreensReadingDatabase(ref.read(appRouterProvider));
              await ref.read(appDatabaseProvider).close();
            },
            invalidateDatabase: () => ref.invalidate(appDatabaseProvider),
          );
    } on FormatException {
      return const BackupSyncFailed(reason: 'invalid_backup_file');
    } on Exception catch (error, stack) {
      ref.read(appLogProvider).error('backup.restore', error, stack);
      return const BackupSyncFailed(reason: 'restore_failed');
    }
    return result;
  } finally {
    _deleteIfExists(downloadedFile.path);
  }
}

void _deleteIfExists(String path) {
  final sidecar = File(path);
  if (sidecar.existsSync()) {
    sidecar.deleteSync();
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  bool _isAutoSyncing = false;
  Future<void> _savedPreferencesLoaded = Future<void>.value();

  @override
  SettingsState build() {
    _savedPreferencesLoaded = _loadAutoBackupPreference();
    return const SettingsState(
      backupStatus: BackupStatus.notConnected,
      autoBackupEnabled: true,
    );
  }

  Future<void> _loadAutoBackupPreference() async {
    final prefs = ref.read(backupPreferencesProvider);
    final enabled = await prefs.readAutoBackupEnabled();
    final wasConnected = await prefs.readBackupConnected();
    final savedEmail = await prefs.readConnectedEmail();
    if (!ref.mounted) return;
    state = state.copyWith(autoBackupEnabled: enabled);
    if (wasConnected && state.backupStatus == BackupStatus.notConnected) {
      if (savedEmail != null) {
        state = state.copyWith(
          backupStatus: BackupStatus.connected,
          accountEmail: savedEmail,
          clearError: true,
        );
      }
    }
  }

  Future<void> connectBackup() async {
    if (state.backupStatus == BackupStatus.connecting) return;
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await ref.read(driveBackupServiceProvider).signIn();
    switch (result) {
      case BackupAuthSuccess(:final email):
        _savePreferenceInBackground(
          ref,
          ref.read(backupPreferencesProvider).writeConnectedEmail(email),
        );
        state = state.copyWith(
          backupStatus: BackupStatus.choosing,
          accountEmail: email,
          clearError: true,
        );
      case BackupAuthCancelled():
        state = state.copyWith(
          backupStatus: BackupStatus.notConnected,
          clearError: true,
        );
      case BackupAuthFailed(:final reason):
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: reason,
        );
    }
  }

  Future<void> choosePhoneData() async {
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await uploadStoreDatabase(ref, allowPrompt: true);
    switch (result) {
      case BackupSyncSuccess():
        _savePreferenceInBackground(
          ref,
          ref.read(backupPreferencesProvider).writeBackupConnected(true),
        );
        state = state.copyWith(
          backupStatus: BackupStatus.connected,
          syncedJustNow: true,
          clearError: true,
        );
      case BackupSyncNoBackup():
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: 'no_backup_found',
        );
      case BackupSyncFailed(:final reason):
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: reason,
        );
    }
  }

  Future<void> chooseRestoreBackup() async {
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await restoreStoreDatabase(ref, allowPrompt: true);
    switch (result) {
      case BackupSyncSuccess():
        _savePreferenceInBackground(
          ref,
          ref.read(backupPreferencesProvider).writeBackupConnected(true),
        );
        state = state.copyWith(
          backupStatus: BackupStatus.connected,
          syncedJustNow: true,
          clearError: true,
        );
      case BackupSyncNoBackup():
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: 'no_backup_found',
        );
      case BackupSyncFailed(:final reason):
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: reason,
        );
    }
  }

  Future<void> syncNow() async {
    if (state.backupStatus != BackupStatus.connected) return;
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await uploadStoreDatabase(ref, allowPrompt: true);
    switch (result) {
      case BackupSyncSuccess():
        state = state.copyWith(
          backupStatus: BackupStatus.connected,
          syncedJustNow: true,
          clearError: true,
        );
      case BackupSyncNoBackup():
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: 'no_backup_found',
        );
      case BackupSyncFailed(:final reason):
        state = state.copyWith(
          backupStatus: BackupStatus.failed,
          errorReason: reason,
        );
    }
  }

  Future<void> retryBackup() => connectBackup();

  Future<void> disconnectBackup() async {
    await ref.read(driveBackupServiceProvider).signOut();
    _savePreferenceInBackground(
      ref,
      ref.read(backupPreferencesProvider).writeBackupConnected(false),
    );
    _savePreferenceInBackground(
      ref,
      ref.read(backupPreferencesProvider).writeConnectedEmail(null),
    );
    state = SettingsState(
      backupStatus: BackupStatus.notConnected,
      autoBackupEnabled: state.autoBackupEnabled,
    );
  }

  void toggleAutoBackup(bool enabled) {
    state = state.copyWith(autoBackupEnabled: enabled);
    _savePreferenceInBackground(
      ref,
      ref.read(backupPreferencesProvider).writeAutoBackupEnabled(enabled),
    );
  }

  Future<void> triggerAutoBackupIfEnabled() async {
    await _savedPreferencesLoaded;
    if (!ref.mounted) return;
    if (state.backupStatus != BackupStatus.connected) return;
    if (!state.autoBackupEnabled) return;
    if (_isAutoSyncing) return;

    _isAutoSyncing = true;
    try {
      final result = await uploadStoreDatabase(ref);
      if (!ref.mounted) return;
      if (result is BackupSyncSuccess) {
        state = state.copyWith(syncedJustNow: true);
      }
    } finally {
      _isAutoSyncing = false;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    unawaited(_loadSavedLocale());
    return const Locale('en');
  }

  Future<void> _loadSavedLocale() async {
    final savedCode = await ref
        .read(backupPreferencesProvider)
        .readLocaleCode();
    if (!ref.mounted || savedCode == null) return;
    if (savedCode == 'en' || savedCode == 'fil') {
      state = Locale(savedCode);
    }
  }

  void setLanguageCode(String code) {
    state = Locale(code);
    _savePreferenceInBackground(
      ref,
      ref.read(backupPreferencesProvider).writeLocaleCode(code),
    );
  }
}

Future<bool> confirmStorePinIfSet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) async {
  if (!await ref.read(storePinServiceProvider).hasPin()) return true;
  if (!context.mounted) return false;
  return verifyStorePin(context, ref, title: title);
}

Future<bool> verifyStorePin(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) async {
  final pinService = ref.read(storePinServiceProvider);
  final biometricService = ref.read(biometricAuthServiceProvider);
  final canUseBiometric = await biometricService.canAuthenticate();
  final connectedEmail = ref.read(settingsNotifierProvider).accountEmail;
  if (!context.mounted) return false;

  return showPinPromptDialog(
    context,
    title: title,
    pinService: pinService,
    onAuthenticateBiometric: canUseBiometric
        ? () => biometricService.authenticate(localizedReason: title)
        : null,
    onRemoveDamagedPin: !canUseBiometric && connectedEmail == null
        ? pinService.clearPin
        : null,
    onResetWithGoogle: () async {
      final authResult = await ref.read(driveBackupServiceProvider).signIn();
      return switch (authResult) {
        BackupAuthSuccess(:final email) =>
          connectedEmail != null &&
              email.toLowerCase() == connectedEmail.toLowerCase(),
        _ => false,
      };
    },
  );
}
