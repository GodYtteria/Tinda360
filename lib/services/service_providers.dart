import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/features/chat/data/yumi_engine.dart';
import 'package:tinda360/services/backup_preferences.dart';
import 'package:tinda360/services/biometric_auth_service.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/local_backup_service.dart';
import 'package:tinda360/services/store_pin_service.dart';

final clockProvider = Provider<Clock>((ref) => const Clock());

final appLogProvider = Provider<AppLog>(
  (ref) => throw UnimplementedError('Override appLogProvider in bootstrap()'),
);

final driveBackupServiceProvider = Provider<DriveBackupService>(
  (ref) => GoogleDriveBackupService(log: ref.watch(appLogProvider)),
);

final localBackupServiceProvider = Provider<LocalBackupService>(
  (ref) => const LocalBackupService(),
);

final backupPreferencesProvider = Provider<BackupPreferencesStore>(
  (ref) => FileBackupPreferencesStore(),
);

final storePinServiceProvider = Provider<StorePinService>(
  (ref) => StorePinService(),
);

final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => BiometricAuthService(),
);

final yumiEngineProvider = Provider<YumiEngine>(
  (ref) => YumiEngine.instance,
);

final yumiWarmupProvider = FutureProvider<void>(
  (ref) => ref.watch(yumiEngineProvider).init(),
);
