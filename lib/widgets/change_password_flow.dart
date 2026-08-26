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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';
import '../services/database_service.dart';
import '../services/key_service.dart';
import '../services/secure_storage_service.dart';
import '../localization/locale_provider.dart';
import 'app_dialogs.dart';
import 'app_snack.dart';

/// Verifies the current password (or an enrolled fingerprint) and re-encrypts
/// every box under a brand-new key derived from the user's chosen new password.
/// Shared by the Security screen and the unlock screen.
Future<void> showChangePasswordFlow(
  BuildContext context,
  WidgetRef ref, {
  bool boxesAlreadyOpen = true,
}) async {
  HapticFeedback.lightImpact();
  final oldKey = await _verifyIdentity(context, ref);
  if (oldKey == null || !context.mounted) return;
  await _showNewPasswordDialog(context, ref, oldKey, boxesAlreadyOpen);
}

Future<Uint8List?> _verifyIdentity(BuildContext context, WidgetRef ref) async {
  final t = ref.read(stringsProvider);
  final secureStorage = SecureStorageService();
  final verifierB64 = await secureStorage.getPasswordVerifier();
  final saltB64 = await secureStorage.getKdfSalt();
  if (verifierB64 == null || saltB64 == null) return null;

  final biometricEnabled =
      await BiometricService(
        secureStorage: secureStorage,
      ).isBiometricLoginEnabled();

  if (!context.mounted) return null;

  if (biometricEnabled) {
    final usesBiometric = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('verify_identity')),
        content: Text(t('verify_identity_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('use_password')),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.fingerprint),
            label: Text(t('use_fingerprint')),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (usesBiometric == null) return null;

    if (usesBiometric) {
      final biometricService = BiometricService(
        secureStorage: secureStorage,
      );
      final authenticated = await biometricService.authenticate();
      if (!authenticated || !context.mounted) return null;
      final keyDataB64 = await secureStorage.getBiometricKeyData();
      if (keyDataB64 == null) return null;
      return base64Decode(keyDataB64);
    }
  }

  if (!context.mounted) return null;
  final password = await _promptCurrentPassword(context, ref);
  if (password == null || password.isEmpty) return null;

  final keyService = KeyService();
  keyService.clearCache();
  final salt = base64Decode(saltB64);
  final derivedKey = await keyService.deriveKey(password, salt);
  final candidate = keyService.computeVerifier(derivedKey);
  final storedVerifier = base64Decode(verifierB64);

  if (!keyService.constantTimeEquals(candidate, storedVerifier)) {
    if (!context.mounted) return null;
    showAppSnack(context, t('incorrect_password'), kind: SnackKind.error);
    return null;
  }
  return derivedKey;
}

Future<String?> _promptCurrentPassword(
  BuildContext context,
  WidgetRef ref,
) {
  final t = ref.read(stringsProvider);
  return showPasswordPromptDialog(
    context,
    title: t('current_password'),
    label: t('enter_current_password'),
    confirmLabel: t('verify'),
    cancelLabel: t('cancel'),
  );
}

Future<void> _showNewPasswordDialog(
  BuildContext context,
  WidgetRef ref,
  Uint8List oldKey,
  bool boxesAlreadyOpen,
) async {
  final t = ref.read(stringsProvider);

  final newPassword = await showNewPasswordDialog(
    context,
    title: t('new_password'),
    passwordLabel: t('new_password'),
    confirmLabel: t('confirm_new_password'),
    submitLabel: t('change_password'),
    cancelLabel: t('cancel'),
    requiredMessage: t('password_required'),
    mismatchMessage: t('passwords_do_not_match'),
    minLength: 6,
    tooShortMessage: t('password_too_short'),
  );

  if (newPassword == null || !context.mounted) return;
  await _performPasswordChange(
    context,
    ref,
    oldKey,
    newPassword,
    boxesAlreadyOpen: boxesAlreadyOpen,
  );
}

Future<void> _performPasswordChange(
  BuildContext context,
  WidgetRef ref,
  Uint8List oldKey,
  String newPassword, {
  required bool boxesAlreadyOpen,
}) async {
  final t = ref.read(stringsProvider);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              t('changing_password'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              t('do_not_close_app'),
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    final db = DatabaseService();
    final keyService = KeyService();
    final secureStorage = SecureStorageService();

    final (newKey, newSalt) = await keyService.deriveNewKey(newPassword);

    try {
      if (!boxesAlreadyOpen) {
        await db.openBoxes(oldKey);
      }
      await db.reEncryptBoxes(oldKey, newKey);

      final newVerifier = keyService.computeVerifier(newKey);
      await secureStorage.savePasswordVerifier(base64Encode(newVerifier));
      await secureStorage.saveKdfSalt(base64Encode(newSalt));

      final biometricEnabled =
          await BiometricService(
            secureStorage: secureStorage,
          ).isBiometricLoginEnabled();

      if (biometricEnabled) {
        final newToken = KeyService.computeBiometricToken(newKey);
        await secureStorage.saveBiometricToken(newToken);
        await secureStorage.saveBiometricKeyData(newKey);
      }
    } finally {
      // Opened here only; must never stay open behind the lock screen.
      if (!boxesAlreadyOpen) {
        await db.closeDataBoxes();
        KeyService().clearCache();
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    showAppSnack(
      context,
      t('password_changed_success'),
      kind: SnackKind.success,
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    showErrorSnack(context, t('failed_change_password'), e);
  }
}