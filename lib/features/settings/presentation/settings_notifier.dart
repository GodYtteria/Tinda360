import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/database_maintenance.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/pin_prompt_dialog.dart';

/// Connection state for Google Drive backup.
enum BackupStatus {
  /// No Google account connected yet (`off`).
  notConnected,

  /// Account picker / sign-in is in progress.
  connecting,

  /// Signed in; user chooses between phone data or Drive backup (`choose`).
  choosing,

  /// Backup is connected and active (`on`).
  connected,

  /// Last backup attempt failed; local data remains safe.
  failed,
}

/// Immutable state for the Settings screen.
final class SettingsState {
  /// Creates a settings state.
  const SettingsState({
    required this.backupStatus,
    required this.autoBackupEnabled,
    this.accountEmail,
    this.syncedJustNow = false,
    this.errorReason,
  });

  /// Current backup connection status.
  final BackupStatus backupStatus;

  /// Whether automatic backup is toggled on (defaults to true, Wi-Fi only).
  final bool autoBackupEnabled;

  /// Connected Google account email, if any.
  final String? accountEmail;

  /// True after "Sync ngayon" or choosing a backup source completes.
  final bool syncedJustNow;

  /// Diagnostic error reason when [backupStatus] is [BackupStatus.failed].
  final String? errorReason;

  /// Returns a copy with updated fields.
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

/// Live stream of the store's profile.
final storeProfileStreamProvider = StreamProvider.autoDispose<StoreProfile>(
  (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
);

/// Riverpod provider for settings backup and preferences state.
final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(
      SettingsNotifier.new,
    );

/// Live disk size in bytes for the active store's SQLite database.
final databaseSizeBytesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(appDatabaseProvider);
  final file = await ref.watch(databaseFileProvider)();
  return measureDatabaseBytes(file);
});

/// Compacts the active database and returns the new size in bytes.
Future<int> compactStoreDatabase(Ref ref) async {
  final database = ref.read(appDatabaseProvider);
  await compactDatabase(database);
  final file = await ref.read(databaseFileProvider)();
  ref.invalidate(databaseSizeBytesProvider);
  return measureDatabaseBytes(file);
}

/// Creates a compacted `VACUUM INTO` snapshot and uploads it to Google Drive.
Future<BackupSyncResult> uploadStoreDatabase(Ref ref) async {
  final database = ref.read(appDatabaseProvider);
  final file = await ref.read(databaseFileProvider)();
  final snapshotFile = File('${file.path}.snapshot');
  try {
    await createCompactedBackupSnapshot(database, snapshotFile);
    final uploadTarget = snapshotFile.existsSync() ? snapshotFile : file;
    return await ref.read(driveBackupServiceProvider).uploadDatabase(uploadTarget);
  } finally {
    if (snapshotFile.existsSync()) {
      snapshotFile.deleteSync();
    }
  }
}

/// Downloads the Google Drive backup, replaces the local SQLite file, and
/// invalidates [appDatabaseProvider] so repositories reopen the restored DB.
Future<BackupSyncResult> restoreStoreDatabase(Ref ref) async {
  final file = await ref.read(databaseFileProvider)();
  final db = ref.read(appDatabaseProvider);
  await db.close();
  final result = await ref.read(driveBackupServiceProvider).downloadDatabaseTo(file);
  if (result is BackupSyncSuccess) {
    _deleteIfExists('${file.path}-wal');
    _deleteIfExists('${file.path}-shm');
  }
  ref.invalidate(appDatabaseProvider);
  return result;
}

void _deleteIfExists(String path) {
  final sidecar = File(path);
  if (sidecar.existsSync()) {
    sidecar.deleteSync();
  }
}

/// Manages backup connection state and auto-backup preference.
class SettingsNotifier extends Notifier<SettingsState> {
  bool _isAutoSyncing = false;

  @override
  SettingsState build() {
    unawaited(_loadAutoBackupPreference());
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
      final restoredEmail =
          await ref.read(driveBackupServiceProvider).restoreSession();
      if (!ref.mounted) return;
      if (restoredEmail != null) {
        unawaited(prefs.writeConnectedEmail(restoredEmail));
        state = state.copyWith(
          backupStatus: BackupStatus.connected,
          accountEmail: restoredEmail,
          clearError: true,
        );
      }
    }
  }

  /// Starts Google Drive backup connection (`off` -> `choose`).
  Future<void> connectBackup() async {
    if (state.backupStatus == BackupStatus.connecting) return;
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await ref.read(driveBackupServiceProvider).signIn();
    switch (result) {
      case BackupAuthSuccess(:final email):
        unawaited(
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

  /// Completes the `choose` step by uploading local phone data (`choose` -> `on`).
  Future<void> choosePhoneData() async {
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await uploadStoreDatabase(ref);
    switch (result) {
      case BackupSyncSuccess():
        unawaited(
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

  /// Completes the `choose` step by restoring Drive backup (`choose` -> `on`).
  Future<void> chooseRestoreBackup() async {
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await restoreStoreDatabase(ref);
    switch (result) {
      case BackupSyncSuccess():
        unawaited(
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

  /// Triggers an immediate sync (`on` state).
  Future<void> syncNow() async {
    if (state.backupStatus != BackupStatus.connected) return;
    state = state.copyWith(
      backupStatus: BackupStatus.connecting,
      clearError: true,
    );
    final result = await uploadStoreDatabase(ref);
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

  /// Retries backup after a failure.
  Future<void> retryBackup() => connectBackup();

  /// Disconnects the current backup account (`on` -> `off`).
  Future<void> disconnectBackup() async {
    await ref.read(driveBackupServiceProvider).signOut();
    unawaited(
      ref.read(backupPreferencesProvider).writeBackupConnected(false),
    );
    unawaited(
      ref.read(backupPreferencesProvider).writeConnectedEmail(null),
    );
    state = SettingsState(
      backupStatus: BackupStatus.notConnected,
      autoBackupEnabled: state.autoBackupEnabled,
    );
  }

  /// Updates and persists the auto-backup toggle.
  void toggleAutoBackup(bool enabled) {
    state = state.copyWith(autoBackupEnabled: enabled);
    unawaited(
      ref.read(backupPreferencesProvider).writeAutoBackupEnabled(enabled),
    );
  }

  /// Quietly uploads the database after a sale when connected and enabled.
  Future<void> triggerAutoBackupIfEnabled() async {
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

/// Active app locale; defaults to English (`en`), switchable to Taglish (`fil`).
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Manages switching between English (`en`) and Filipino (`fil`).
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    unawaited(_loadSavedLocale());
    return const Locale('en');
  }

  Future<void> _loadSavedLocale() async {
    final savedCode = await ref.read(backupPreferencesProvider).readLocaleCode();
    if (!ref.mounted || savedCode == null) return;
    if (savedCode == 'en' || savedCode == 'fil') {
      state = Locale(savedCode);
    }
  }

  /// Switches the active locale by language code (`'fil'` or `'en'`).
  void setLanguageCode(String code) {
    state = Locale(code);
    unawaited(ref.read(backupPreferencesProvider).writeLocaleCode(code));
  }
}

/// Prompts for the 4-digit store PIN with biometric unlock and recovery reset.
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
    onResetWithGoogle: () async {
      final authResult = await ref.read(driveBackupServiceProvider).signIn();
      return switch (authResult) {
        BackupAuthSuccess(:final email) =>
          connectedEmail == null ||
          email.toLowerCase() == connectedEmail.toLowerCase(),
        _ => false,
      };
    },
  );
}
