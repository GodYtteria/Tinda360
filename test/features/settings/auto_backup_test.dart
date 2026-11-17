import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/services/backup_preferences.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';

import '../../support/test_repositories.dart';

final class _FakeDriveBackupService implements DriveBackupService {
  int uploadCount = 0;

  @override
  Future<BackupAuthResult> signIn() async =>
      const BackupAuthSuccess(email: 'owner@example.com');

  @override
  Future<String?> restoreSession() async => 'owner@example.com';

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async {
    uploadCount++;
    return const BackupSyncSuccess();
  }

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async =>
      const BackupSyncSuccess();
}

final class _MemoryBackupPrefs implements BackupPreferencesStore {
  bool stored = true;
  bool connected = false;
  String? localeCode;
  String? connectedEmail;

  @override
  Future<bool> readAutoBackupEnabled() async => stored;

  @override
  Future<void> writeAutoBackupEnabled(bool enabled) async {
    stored = enabled;
  }

  @override
  Future<bool> readBackupConnected() async => connected;

  @override
  Future<void> writeBackupConnected(bool isConnected) async {
    connected = isConnected;
  }

  @override
  Future<String?> readConnectedEmail() async => connectedEmail;

  @override
  Future<void> writeConnectedEmail(String? email) async {
    connectedEmail = email;
  }

  @override
  Future<String?> readLocaleCode() async => localeCode;

  @override
  Future<void> writeLocaleCode(String code) async {
    localeCode = code;
  }
}

void main() {
  test('FileBackupPreferencesStore persists toggle across instances', () async {
    final tempDirectory =
        Directory.systemTemp.createTempSync('tinda360_prefs_test_');
    addTearDown(() => tempDirectory.deleteSync(recursive: true));

    final storeOne = FileBackupPreferencesStore(
      directoryProvider: () async => tempDirectory,
    );
    expect(await storeOne.readAutoBackupEnabled(), isTrue);

    await storeOne.writeAutoBackupEnabled(false);
    await storeOne.writeBackupConnected(true);
    await storeOne.writeConnectedEmail('owner@tinda360.com');

    final storeTwo = FileBackupPreferencesStore(
      directoryProvider: () async => tempDirectory,
    );
    expect(await storeTwo.readAutoBackupEnabled(), isFalse);
    expect(await storeTwo.readBackupConnected(), isTrue);
    expect(await storeTwo.readConnectedEmail(), 'owner@tinda360.com');
  });

  test('triggerAutoBackupIfEnabled uploads only when connected and enabled',
      () async {
    final tempDirectory =
        Directory.systemTemp.createTempSync('tinda360_auto_backup_test_');
    addTearDown(() => tempDirectory.deleteSync(recursive: true));
    final dbFile = File('${tempDirectory.path}/test.sqlite')
      ..writeAsStringSync('sqlite');

    final repos = TestRepositories();
    addTearDown(() => repos.db.close());

    final fakeDrive = _FakeDriveBackupService();
    final memoryPrefs = _MemoryBackupPrefs();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        databaseFileProvider.overrideWithValue(() async => dbFile),
        driveBackupServiceProvider.overrideWithValue(fakeDrive),
        backupPreferencesProvider.overrideWithValue(memoryPrefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(settingsNotifierProvider.notifier);

    await notifier.triggerAutoBackupIfEnabled();
    expect(fakeDrive.uploadCount, 0);

    await notifier.connectBackup();
    await notifier.choosePhoneData();
    expect(fakeDrive.uploadCount, 1);

    await notifier.triggerAutoBackupIfEnabled();
    expect(fakeDrive.uploadCount, 2);

    notifier.toggleAutoBackup(false);
    expect(memoryPrefs.stored, isFalse);

    await notifier.triggerAutoBackupIfEnabled();
    expect(fakeDrive.uploadCount, 2);
  });
}
