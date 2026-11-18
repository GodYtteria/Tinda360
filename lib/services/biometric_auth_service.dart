import 'package:local_auth/local_auth.dart';

final class BiometricAuthService {
  new({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

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
