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
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto_lib;

class KeyService {
  static const int saltLength = 16;
  static const int keyLength = 32;
  static const int iterations = 100000;
  static const String _verifierMessage = 'finance_me_local_verifier';
  static const String _biometricMessage = 'finance_me_local_biometric';

  Uint8List? _cachedKey;

  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<Uint8List> deriveKey(String password, Uint8List salt) async {
    if (_cachedKey != null) return _cachedKey!;
    final result = await Isolate.run(() => _stretchKey(password, salt));
    _cachedKey = result;
    return result;
  }

  Future<(Uint8List key, Uint8List salt)> deriveNewKey(
    String newPassword,
  ) async {
    final newSalt = generateSalt();
    final newKey = await Isolate.run(
      () => _stretchKey(newPassword, newSalt),
    );
    return (newKey, newSalt);
  }

  void clearCache() {
    _cachedKey = null;
  }

  /// Runs PBKDF2 on a background isolate
  /// so the UI thread stays responsive during password verification.
  static Future<Uint8List> _stretchKey(
    String password,
    Uint8List salt,
  ) async {
    final algorithm = crypto_lib.Pbkdf2(
      macAlgorithm: crypto_lib.Hmac.sha256(),
      iterations: iterations,
      bits: keyLength * 8,
    );
    final secretKey = await algorithm.deriveKey(
      secretKey: crypto_lib.SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Computes HMAC-SHA256(derivedKey, verifierMessage).
  /// Used to verify a password before opening encrypted Hive boxes.
  Uint8List computeVerifier(Uint8List derivedKey) {
    final hmac = Hmac(sha256, derivedKey);
    final digest = hmac.convert(utf8.encode(_verifierMessage));
    return Uint8List.fromList(digest.bytes);
  }

  /// Computes HMAC-SHA256(derivedKey, biometricMessage).
  /// Used to derive a biometric verification token instead of storing
  /// the plaintext password.
  static Uint8List computeBiometricToken(Uint8List derivedKey) {
    final hmac = Hmac(sha256, derivedKey);
    final digest = hmac.convert(utf8.encode(_biometricMessage));
    return Uint8List.fromList(digest.bytes);
  }

  /// Constant-time comparison of two byte lists.
  /// Prevents timing attacks on password verification.
  bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
