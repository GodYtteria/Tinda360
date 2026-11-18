import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/services/backup_preferences.dart';
import 'package:tinda360/services/backup_status.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';

import '../../support/recording_app_log.dart';
import '../../support/test_repositories.dart';

final class _FakeDriveBackupService implements DriveBackupService {
  int uploadCount = 0;
  int uploadsRunning = 0;
  int mostUploadsAtOnce = 0;
  String? lastUploadAccountEmail;

  @override
  Future<BackupAuthResult> signIn() async =>
      const BackupAuthSuccess(email: 'owner@example.com');

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  }) async {
    lastUploadAccountEmail = accountEmail;
    uploadCount++;
    uploadsRunning++;
    if (uploadsRunning > mostUploadsAtOnce) mostUploadsAtOnce = uploadsRunning;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    uploadsRunning--;
    return const BackupSyncSuccess();
  }

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  }) async => const BackupSyncSuccess();
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

final _uploadOnceProvider = FutureProvider<BackupSyncResult>(
  uploadStoreDatabase,
);

void main() {
  test('FileBackupPreferencesStore persists toggle across instances', () async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_prefs_test_',
    );
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

  test(
    'a failed preference write reaches the caller and later writes work',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'tinda360_prefs_fail_test_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      var directoryRequests = 0;
      final store = FileBackupPreferencesStore(
        directoryProvider: () async {
          directoryRequests++;
          if (directoryRequests == 1) {
            throw const FileSystemException('storage full');
          }
          return tempDirectory;
        },
      );

      await expectLater(
        store.writeConnectedEmail('owner@tinda360.com'),
        throwsA(isA<FileSystemException>()),
      );
      await store.writeConnectedEmail('owner@tinda360.com');
      expect(await store.readConnectedEmail(), 'owner@tinda360.com');
    },
  );

  test('concurrent preference writes never overwrite each other', () async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_prefs_race_test_',
    );
    addTearDown(() => tempDirectory.deleteSync(recursive: true));
    final store = FileBackupPreferencesStore(
      directoryProvider: () async => tempDirectory,
    );

    await Future.wait([
      store.writeBackupConnected(true),
      store.writeConnectedEmail('suki@tinda360.com'),
      store.writeAutoBackupEnabled(false),
      store.writeLocaleCode('fil'),
    ]);

    final reread = FileBackupPreferencesStore(
      directoryProvider: () async => tempDirectory,
    );
    expect(await reread.readBackupConnected(), isTrue);
    expect(await reread.readConnectedEmail(), 'suki@tinda360.com');
    expect(await reread.readAutoBackupEnabled(), isFalse);
    expect(await reread.readLocaleCode(), 'fil');

    await store.writeConnectedEmail(null);
    expect(await reread.readConnectedEmail(), isNull);
    expect(await reread.readBackupConnected(), isTrue);
  });

  test(
    'triggerAutoBackupIfEnabled uploads only when connected and enabled',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'tinda360_auto_backup_test_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final dbFile = File('${tempDirectory.path}/test.sqlite')
        ..writeAsStringSync('sqlite');

      final repos = TestRepositories();
      addTearDown(repos.db.close);

      final fakeDrive = _FakeDriveBackupService();
      final memoryPrefs = _MemoryBackupPrefs();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(repos.db),
          appLogProvider.overrideWithValue(repos.log),
          databaseFileProvider.overrideWithValue(() async => dbFile),
          driveBackupServiceProvider.overrideWithValue(fakeDrive),
          backupStatusStoreProvider.overrideWithValue(
            FileBackupStatusStore(directoryProvider: () async => tempDirectory),
          ),
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
      expect(repos.log.events, isEmpty);
    },
  );

  test('first sale after app restart still auto-backs up', () async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_restart_backup_test_',
    );
    addTearDown(() => tempDirectory.deleteSync(recursive: true));
    final dbFile = File('${tempDirectory.path}/restart.sqlite');
    final repos = TestRepositories();
    addTearDown(repos.db.close);
    final fakeDrive = _FakeDriveBackupService();
    final savedPrefs = _MemoryBackupPrefs()
      ..connected = true
      ..connectedEmail = 'owner@example.com';
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        appLogProvider.overrideWithValue(repos.log),
        databaseFileProvider.overrideWithValue(() async => dbFile),
        driveBackupServiceProvider.overrideWithValue(fakeDrive),
        backupStatusStoreProvider.overrideWithValue(
          FileBackupStatusStore(directoryProvider: () async => tempDirectory),
        ),
        backupPreferencesProvider.overrideWithValue(savedPrefs),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(settingsNotifierProvider.notifier)
        .triggerAutoBackupIfEnabled();

    expect(fakeDrive.uploadCount, 1);
    expect(fakeDrive.lastUploadAccountEmail, 'owner@example.com');
  });

  test('a backup still succeeds when its time cannot be saved', () async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_status_fail_test_',
    );
    addTearDown(() => tempDirectory.deleteSync(recursive: true));
    final dbFile = File('${tempDirectory.path}/status.sqlite');
    final repos = TestRepositories();
    addTearDown(repos.db.close);
    final fakeDrive = _FakeDriveBackupService();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        appLogProvider.overrideWithValue(repos.log),
        databaseFileProvider.overrideWithValue(() async => dbFile),
        driveBackupServiceProvider.overrideWithValue(fakeDrive),
        backupStatusStoreProvider.overrideWithValue(
          FileBackupStatusStore(
            directoryProvider: () async =>
                throw const FileSystemException('storage full'),
          ),
        ),
        backupPreferencesProvider.overrideWithValue(_MemoryBackupPrefs()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(_uploadOnceProvider.future);

    expect(result, isA<BackupSyncSuccess>());
    expect(fakeDrive.uploadCount, 1);
    expect(repos.log.events, contains('backup.status'));
  });

  test('two uploads started together run one after the other', () async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'tinda360_upload_queue_test_',
    );
    addTearDown(() => tempDirectory.deleteSync(recursive: true));
    final dbFile = File('${tempDirectory.path}/queue.sqlite');
    final repos = TestRepositories();
    addTearDown(repos.db.close);
    final fakeDrive = _FakeDriveBackupService();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        appLogProvider.overrideWithValue(repos.log),
        databaseFileProvider.overrideWithValue(() async => dbFile),
        driveBackupServiceProvider.overrideWithValue(fakeDrive),
        backupStatusStoreProvider.overrideWithValue(
          FileBackupStatusStore(directoryProvider: () async => tempDirectory),
        ),
        backupPreferencesProvider.overrideWithValue(_MemoryBackupPrefs()),
      ],
    );
    addTearDown(container.dispose);
    final uploader = Provider<Future<List<BackupSyncResult>>>(
      (ref) => Future.wait([
        uploadStoreDatabase(ref),
        uploadStoreDatabase(ref),
        uploadStoreDatabase(ref),
      ]),
    );

    final results = await container.read(uploader);

    expect(results, everyElement(isA<BackupSyncSuccess>()));
    expect(fakeDrive.uploadCount, 3);
    expect(fakeDrive.mostUploadsAtOnce, 1);
  });

  test(
    'an upload whose snapshot cannot be written fails without throwing',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'tinda360_upload_fail_test_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final dbFile = File('${tempDirectory.path}/missing_dir/store.sqlite');
      final repos = TestRepositories();
      addTearDown(repos.db.close);
      final fakeDrive = _FakeDriveBackupService();
      final log = RecordingAppLog();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(repos.db),
          databaseFileProvider.overrideWithValue(() async => dbFile),
          driveBackupServiceProvider.overrideWithValue(fakeDrive),
          backupStatusStoreProvider.overrideWithValue(
            FileBackupStatusStore(directoryProvider: () async => tempDirectory),
          ),
          backupPreferencesProvider.overrideWithValue(_MemoryBackupPrefs()),
          appLogProvider.overrideWithValue(log),
        ],
      );
      addTearDown(container.dispose);
      final uploader = Provider<Future<BackupSyncResult>>(
        uploadStoreDatabase,
      );

      final result = await container.read(uploader);

      expect(result, isA<BackupSyncFailed>());
      expect(fakeDrive.uploadCount, 0);
      expect(log.events, contains('backup.upload'));
    },
  );
}
