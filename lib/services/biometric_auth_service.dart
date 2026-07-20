import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] for device biometric and credential checks.
final class BiometricAuthService {
  /// Creates a [BiometricAuthService] backed by [localAuthentication], or a
  /// default [LocalAuthentication] instance when omitted.
  new({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  /// Returns whether the device supports biometric or local authentication.
  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      if (canCheckBiometrics) {
        return true;
      }
      return await _localAuthentication.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  /// Prompts the user to authenticate with [localizedReason], returning `false`
  /// if authentication is canceled or fails.
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: localizedReason,
      );
    } on Object {
      return false;
    }
  }
}
