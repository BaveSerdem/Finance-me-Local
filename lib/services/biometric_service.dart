import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';

/// Service handling biometric authentication via platform APIs.
class BiometricService {
  BiometricService({
    required this._secureStorage,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth;

  /// Returns whether the device supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && deviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types on the device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Prompts the user to authenticate using their enrolled biometric.
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Finance me Local',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Returns whether the user has opted into biometric login.
  Future<bool> isBiometricLoginEnabled() async {
    return _secureStorage.isBiometricEnabled();
  }

  /// Toggles biometric login on or off.
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    await _secureStorage.setBiometricEnabled(enabled);
  }
}
