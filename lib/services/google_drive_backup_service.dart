import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tinda360/core/app_log.dart';

sealed class BackupAuthResult {
  const new();
}

final class BackupAuthSuccess extends BackupAuthResult {
  const new({required this.email});

  final String email;
}

final class BackupAuthCancelled extends BackupAuthResult {
  const new();
}

final class BackupAuthFailed extends BackupAuthResult {
  const new({required this.reason});

  final String reason;
}

sealed class BackupSyncResult {
  const new();
}

final class BackupSyncSuccess extends BackupSyncResult {
  const new();
}

final class BackupSyncNoBackup extends BackupSyncResult {
  const new();
}

final class BackupSyncFailed extends BackupSyncResult {
  const new({required this.reason});

  final String reason;
}

abstract interface class DriveBackupService {
  Future<BackupAuthResult> signIn();

  Future<void> signOut();

  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  });

  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  });
}

final class GoogleDriveBackupService implements DriveBackupService {
  new({required this._log});

  static const String _legacyBackupFileName = 'tinda360_backup.sqlite';

  static String backupFileNameForStore(String storeId) {
    if (storeId.isEmpty || storeId == 'default') return _legacyBackupFileName;
    final safe = storeId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    if (safe.isEmpty) return _legacyBackupFileName;
    return 'tinda360_backup_$safe.sqlite';
  }

  static const List<String> _scopes = <String>[
    drive.DriveApi.driveAppdataScope,
  ];
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
      return const BackupAuthFailed(reason: 'sign_in_error');
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
    required String? accountEmail,
    bool allowPrompt = false,
  }) async {
    if (!databaseFile.existsSync()) {
      return const BackupSyncFailed(reason: 'missing_local_database');
    }
    final backupFileName = backupFileNameForStore(storeId);
    return _withDriveApi(
      (driveApi) async {
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
      },
      accountEmail: accountEmail,
      allowPrompt: allowPrompt,
    );
  }

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  }) async {
    final backupFileName = backupFileNameForStore(storeId);
    return _withDriveApi(
      (driveApi) async {
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
        } on Object {
          try {
            await sink.close();
          } on Object catch (closeError, closeStack) {
            _log.error('drive.download_close', closeError, closeStack);
          } finally {
            if (stagingFile.existsSync()) stagingFile.deleteSync();
          }
          rethrow;
        }
        await sink.close();
        await destinationFile.parent.create(recursive: true);
        await stagingFile.rename(destinationFile.path);
        return const BackupSyncSuccess();
      },
      accountEmail: accountEmail,
      allowPrompt: allowPrompt,
    );
  }

  Future<BackupSyncResult> _withDriveApi(
    Future<BackupSyncResult> Function(drive.DriveApi driveApi) action, {
    required String? accountEmail,
    required bool allowPrompt,
  }) async {
    final signedInAccount = _account;
    final usesSignedInAccount =
        signedInAccount != null &&
        (accountEmail == null ||
            signedInAccount.email.toLowerCase() == accountEmail.toLowerCase());
    if (!usesSignedInAccount && accountEmail == null) {
      return const BackupSyncFailed(reason: 'not_signed_in');
    }
    http.Client? baseClient;
    try {
      final headers = usesSignedInAccount
          ? await signedInAccount.authorizationClient.authorizationHeaders(
              _scopes,
              promptIfNecessary: allowPrompt,
            )
          : await _authorizationHeadersForEmail(
              accountEmail!,
              allowPrompt: allowPrompt,
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
      return const BackupSyncFailed(reason: 'drive_error');
    } finally {
      baseClient?.close();
    }
  }

  Future<Map<String, String>?> _authorizationHeadersForEmail(
    String accountEmail, {
    required bool allowPrompt,
  }) async {
    await _ensureInitialized();
    final tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: _scopes,
              userId: null,
              email: accountEmail,
              promptIfUnauthorized: allowPrompt,
            ),
          ),
        );
    if (tokens == null) return null;
    return <String, String>{'Authorization': 'Bearer ${tokens.accessToken}'};
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
  new(this._headers, this._inner);

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
