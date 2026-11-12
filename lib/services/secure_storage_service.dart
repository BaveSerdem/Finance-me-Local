// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database_service.dart';

/// Service wrapping [FlutterSecureStorage] for reading and writing
/// sensitive local configuration (biometric status, EULA, etc.).
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _eulaAcceptedKey = 'eula_accepted';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String passwordVerifierKey = 'password_verifier';
  static const String kdfSaltKey = 'kdf_salt';
  static const String biometricTokenKey = 'biometric_token';
  static const String biometricKeyDataKey = 'biometric_key_data';

  /// Plain-settings copies of the salt and the HMAC verifier (M-4).
  ///
  /// Neither is secret: the salt only makes the derivation unique and the
  /// verifier is an HMAC that cannot be inverted into the key. Keeping a copy
  /// outside the Keystore-backed store means a lost or reset Keystore no
  /// longer turns a known password into a permanently locked vault. Key
  /// material is never mirrored.
  static const String passwordVerifierMirrorKey = 'password_verifier_mirror';
  static const String kdfSaltMirrorKey = 'kdf_salt_mirror';

  // ---------------------------------------------------------------------------
  // Biometric authentication flag
  // ---------------------------------------------------------------------------

  /// Persists the biometric-enabled preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// Returns whether biometric authentication is enabled.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value?.toLowerCase() == 'true';
  }

  /// Removes the biometric preference.
  Future<void> deleteBiometricPreference() async {
    await _storage.delete(key: _biometricEnabledKey);
  }

  // ---------------------------------------------------------------------------
  // EULA acceptance flag
  // ---------------------------------------------------------------------------

  /// Persists the EULA acceptance status.
  Future<void> setEulaAccepted(bool accepted) async {
    await _storage.write(key: _eulaAcceptedKey, value: accepted.toString());
  }

  /// Returns whether the user has accepted the EULA.
  Future<bool> isEulaAccepted() async {
    final value = await _storage.read(key: _eulaAcceptedKey);
    return value?.toLowerCase() == 'true';
  }

  // ---------------------------------------------------------------------------
  // Password verifier
  // ---------------------------------------------------------------------------

  /// Saves the HMAC-SHA256 password verifier (base64-encoded).
  ///
  /// The mirror is written first: if the process dies between the two writes
  /// the secure copy is still the old one and wins on read, which is the
  /// consistent state; a mirror that is newer than the secure copy is only
  /// ever consulted once the secure copy is gone.
  Future<void> savePasswordVerifier(String verifier) async {
    await _writeMirror(passwordVerifierMirrorKey, verifier);
    await _storage.write(key: passwordVerifierKey, value: verifier);
  }

  /// Returns the stored password verifier, or null if not set.
  Future<String?> getPasswordVerifier() async {
    return await _readSecure(passwordVerifierKey) ??
        _readMirror(passwordVerifierMirrorKey);
  }

  /// Saves the KDF salt (base64-encoded).
  Future<void> saveKdfSalt(String salt) async {
    await _writeMirror(kdfSaltMirrorKey, salt);
    await _storage.write(key: kdfSaltKey, value: salt);
  }

  /// Returns the stored KDF salt, or null if not set.
  Future<String?> getKdfSalt() async {
    return await _readSecure(kdfSaltKey) ?? _readMirror(kdfSaltMirrorKey);
  }

  /// Back-fills the mirrors for a vault created before they existed. Called
  /// after a successful password verification, so the values are known good.
  Future<void> mirrorIdentityIfMissing({
    required String verifier,
    required String salt,
  }) async {
    if (_readMirror(passwordVerifierMirrorKey) == null) {
      await _writeMirror(passwordVerifierMirrorKey, verifier);
    }
    if (_readMirror(kdfSaltMirrorKey) == null) {
      await _writeMirror(kdfSaltMirrorKey, salt);
    }
  }

  /// A Keystore that has been wiped can make the plugin throw rather than
  /// return null; either way the mirror is the fallback.
  Future<String?> _readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  String? _readMirror(String key) {
    final db = DatabaseService();
    if (!db.isInitialized) return null;
    final value = db.settingsBox.get(key);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> _writeMirror(String key, String value) async {
    final db = DatabaseService();
    if (!db.isInitialized) return;
    await db.settingsBox.put(key, value);
  }

  // ---------------------------------------------------------------------------
  // Biometric token (derived from key, not plaintext password)
  // ---------------------------------------------------------------------------

  /// Saves the HMAC-SHA256 biometric verification token.
  Future<void> saveBiometricToken(Uint8List token) async {
    await _storage.write(
      key: biometricTokenKey,
      value: base64Encode(token),
    );
  }

  /// Returns the stored biometric token (base64-encoded), or null.
  Future<String?> getBiometricToken() async {
    return _storage.read(key: biometricTokenKey);
  }

  /// Removes the biometric token from storage.
  Future<void> deleteBiometricToken() async {
    await _storage.delete(key: biometricTokenKey);
  }

  /// Saves the derived AES key for biometric unlock (base64-encoded).
  /// This replaces the old pattern of storing the plaintext password.
  Future<void> saveBiometricKeyData(Uint8List keyData) async {
    await _storage.write(
      key: biometricKeyDataKey,
      value: base64Encode(keyData),
    );
  }

  /// Returns the stored derived key (base64-encoded), or null.
  Future<String?> getBiometricKeyData() async {
    return _storage.read(key: biometricKeyDataKey);
  }

  /// Removes the stored derived key.
  Future<void> deleteBiometricKeyData() async {
    await _storage.delete(key: biometricKeyDataKey);
  }

  // ---------------------------------------------------------------------------
  // Generic helpers
  // ---------------------------------------------------------------------------

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return _storage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
