import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth`.
///
/// The biometric check never produces the key by itself: it gates reading the
/// copy that already sits in the Keystore/Keychain.
class BiometricService {
  BiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether the device has hardware and at least one enrolled biometric.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException {
      return const [];
    }
  }

  /// Prompts the user. Returns false on cancel, lockout or missing hardware.
  Future<bool> authenticate({
    String reason = 'Ontgrendel FitLog om je trainingen te bekijken',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        // The prompt stays up when the system briefly backgrounds the app.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
