import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/services/backup_preferences.dart';
import 'package:tinda360/services/biometric_auth_service.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/local_backup_service.dart';
import 'package:tinda360/services/store_pin_service.dart';

/// The one source of "now". Tests override it with `Clock.fixed`.
final clockProvider = Provider<Clock>((ref) => const Clock());

/// The local error log. Throws until bootstrap() overrides it.
final appLogProvider = Provider<AppLog>(
  (ref) => throw UnimplementedError('Override appLogProvider in bootstrap()'),
);

/// Google Drive backup and restore service.
final driveBackupServiceProvider = Provider<DriveBackupService>(
  (ref) => GoogleDriveBackupService(log: ref.watch(appLogProvider)),
);

/// Local `.sqlite` file backup export and import service.
final localBackupServiceProvider = Provider<LocalBackupService>(
  (ref) => const LocalBackupService(),
);

/// Persisted backup preferences store.
final backupPreferencesProvider = Provider<BackupPreferencesStore>(
  (ref) => FileBackupPreferencesStore(),
);

/// 4-digit store PIN lock service.
final storePinServiceProvider = Provider<StorePinService>(
  (ref) => StorePinService(),
);

/// Device biometric authentication service.
final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => BiometricAuthService(),
);
