import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tinda360/core/app_log.dart';

/// Result of signing in with a Google account for Drive backup.
sealed class BackupAuthResult {
  const BackupAuthResult();
}

/// Sign-in succeeded with [email].
final class BackupAuthSuccess extends BackupAuthResult {
  /// Creates a successful sign-in result.
  const BackupAuthSuccess({required this.email});

  /// Signed-in Google account email.
  final String email;
}

/// User dismissed the Google sign-in sheet.
final class BackupAuthCancelled extends BackupAuthResult {
  /// Creates a cancelled sign-in result.
  const BackupAuthCancelled();
}

/// Sign-in failed due to configuration, Play Services, or network error.
final class BackupAuthFailed extends BackupAuthResult {
  /// Creates a failed sign-in result.
  const BackupAuthFailed({required this.reason});

  /// Short diagnostic reason.
  final String reason;
}

/// Result of uploading or restoring the database backup file.
sealed class BackupSyncResult {
  const BackupSyncResult();
}

/// Upload or restore completed successfully.
final class BackupSyncSuccess extends BackupSyncResult {
  /// Creates a successful sync result.
  const BackupSyncSuccess();
}

/// No backup file exists yet in Google Drive's appDataFolder.
final class BackupSyncNoBackup extends BackupSyncResult {
  /// Creates a no-backup result.
  const BackupSyncNoBackup();
}

/// Upload or restore failed.
final class BackupSyncFailed extends BackupSyncResult {
  /// Creates a failed sync result.
  const BackupSyncFailed({required this.reason});

  /// Short diagnostic reason.
  final String reason;
}

/// Abstraction for Google Drive app-folder backup and restore.
abstract interface class DriveBackupService {
  /// Signs in and returns the selected account email.
  Future<BackupAuthResult> signIn();

  /// Silently restores a previously signed-in account, or returns null.
  Future<String?> restoreSession();

  /// Signs out and disconnects the Google session.
  Future<void> signOut();

  /// Uploads [databaseFile] to the user's private Google Drive appDataFolder.
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    bool allowPrompt = false,
  });

  /// Downloads the backup into [destinationFile] (replacing it atomically).
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    bool allowPrompt = false,
  });
}

/// Google Sign-In + Google Drive `drive.appdata` implementation.
final class GoogleDriveBackupService implements DriveBackupService {
  /// Creates the service.
  GoogleDriveBackupService({required AppLog log}) : _log = log;

  static const String _legacyBackupFileName = 'tinda360_backup.sqlite';

  /// Each store gets its own Drive file so syncing one store cannot overwrite
  /// another store's backup.
  static String backupFileNameForStore(String storeId) {
    if (storeId.isEmpty || storeId == 'default') return _legacyBackupFileName;
    final safe = storeId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    if (safe.isEmpty) return _legacyBackupFileName;
    return 'tinda360_backup_$safe.sqlite';
  }
  static const List<String> _scopes = <String>[drive.DriveApi.driveAppdataScope];
  static const String _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  final AppLog _log;
  bool _initialized = false;
  GoogleSignInAccount? _account;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: _clientId.isEmpty ? null : _clientId,
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  @override
  Future<String?> restoreSession() async {
    try {
      await _ensureInitialized();
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = attempt is Future<GoogleSignInAccount?>
          ? await attempt
          : attempt;
      if (account == null) return null;
      _account = account;
      return account.email;
    } on Object {
      return null;
    }
  }

  @override
  Future<BackupAuthResult> signIn() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      _account = account;
      return BackupAuthSuccess(email: account.email);
    } on GoogleSignInException catch (error, stack) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return const BackupAuthCancelled();
      }
      _log.error('backup.signIn', error, stack);
      return BackupAuthFailed(reason: error.code.name);
    } on Exception catch (error, stack) {
      _log.error('backup.signIn', error, stack);
      return BackupAuthFailed(reason: error.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.disconnect();
    } on Exception catch (error, stack) {
      _log.error('backup.signOut', error, stack);
    } finally {
      _account = null;
    }
  }

  @override
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async {
    if (!databaseFile.existsSync()) {
      return const BackupSyncFailed(reason: 'missing_local_database');
    }
    if (_account == null && allowPrompt) await restoreSession();
    final backupFileName = backupFileNameForStore(storeId);
    return _withDriveApi((driveApi) async {
      final existingId = await _findBackupFileId(driveApi, backupFileName);
      final length = await databaseFile.length();
      final media = drive.Media(databaseFile.openRead(), length);
      final metadata = drive.File()..name = backupFileName;
      if (existingId != null) {
        await driveApi.files.update(metadata, existingId, uploadMedia: media);
      } else {
        metadata.parents = const <String>['appDataFolder'];
        await driveApi.files.create(metadata, uploadMedia: media);
      }
      return const BackupSyncSuccess();
    }, allowPrompt: allowPrompt);
  }

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async {
    if (_account == null && allowPrompt) await restoreSession();
    final backupFileName = backupFileNameForStore(storeId);
    return _withDriveApi((driveApi) async {
      final existingId = await _findBackupFileId(driveApi, backupFileName);
      if (existingId == null) {
        return const BackupSyncNoBackup();
      }
      final response = await driveApi.files.get(
        existingId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        return const BackupSyncFailed(reason: 'invalid_media_response');
      }
      final stagingFile = File('${destinationFile.path}.restore');
      final sink = stagingFile.openWrite();
      try {
        await sink.addStream(response.stream);
        await sink.flush();
      } finally {
        await sink.close();
      }
      await destinationFile.parent.create(recursive: true);
      await stagingFile.rename(destinationFile.path);
      return const BackupSyncSuccess();
    }, allowPrompt: allowPrompt);
  }

  Future<BackupSyncResult> _withDriveApi(
    Future<BackupSyncResult> Function(drive.DriveApi driveApi) action, {
    bool allowPrompt = false,
  }) async {
    final account = _account;
    if (account == null) {
      return const BackupSyncFailed(reason: 'not_signed_in');
    }
    http.Client? baseClient;
    try {
      final headers = await account.authorizationClient.authorizationHeaders(
        _scopes,
        promptIfNecessary: allowPrompt,
      );
      if (headers == null) {
        return const BackupSyncFailed(reason: 'authorization_denied');
      }
      baseClient = http.Client();
      final authClient = _GoogleAuthHttpClient(headers, baseClient);
      final driveApi = drive.DriveApi(authClient);
      return await action(driveApi);
    } on Exception catch (error, stack) {
      _log.error('backup.drive', error, stack);
      return BackupSyncFailed(reason: error.toString());
    } finally {
      baseClient?.close();
    }
  }

  Future<String?> _findBackupFileId(
    drive.DriveApi driveApi,
    String backupFileName,
  ) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFileName' and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1,
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}

final class _GoogleAuthHttpClient extends http.BaseClient {
  _GoogleAuthHttpClient(this._headers, this._inner);

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
