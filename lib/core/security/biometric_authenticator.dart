import 'package:local_auth/local_auth.dart';

enum BiometricResult {
  authenticated,

  /// The user cancelled or failed; the protected action must not happen.
  denied,

  /// The device has no biometrics or screen lock; nothing to verify with.
  unavailable,
}

/// Confirms the user's identity before showing sensitive data (RN-30).
abstract interface class BiometricAuthenticator {
  Future<BiometricResult> authenticate({required String reason});
}

/// Biometrics, falling back to the device PIN/pattern when allowed by the
/// system, through `local_auth`.
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  new([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricResult.unavailable;
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? BiometricResult.authenticated
          : BiometricResult.denied;
    } on Object {
      // Any platform error keeps the data hidden (fail closed).
      return BiometricResult.denied;
    }
  }
}
