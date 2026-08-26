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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';
import '../services/database_service.dart';
import '../services/key_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/biometric_enrollment.dart';
import 'app_dialogs.dart';
import 'app_snack.dart';

/// Enables encryption for an app currently running with unencrypted boxes.
///
/// Doorway for users who opted out on first launch (so
/// `DatabaseService().getEncryptionChoice() == false`). Walks password
/// creation → blocking progress → re-encrypt onto the new cipher → persist
/// identity → back to the now-lit Security screen.
///
/// The re-encryption reuses [`DatabaseService.enableEncryption`] — the same
/// underlying deep-copy path as the change-password flow — rather than any
/// new box migration. SecureStorage writes happen only after the re-encryption
/// succeeds without throwing, so the app is never left half-encrypted.
Future<void> showEnableEncryptionFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final t = ref.read(stringsProvider);

  final password = await showNewPasswordDialog(
    context,
    title: t('enable_encryption_now_title'),
    passwordLabel: t('password'),
    confirmLabel: t('confirm_password'),
    submitLabel: t('proceed'),
    cancelLabel: t('cancel'),
    requiredMessage: t('password_required'),
    mismatchMessage: t('passwords_do_not_match'),
    minLength: 6,
    tooShortMessage: t('password_too_short'),
  );

  if (password == null || password.isEmpty || !context.mounted) return;

  final progressContext = _showProgressDialog(context, ref);

  try {
    final secureStorage = SecureStorageService();
    final keyService = KeyService();
    // Never trust a stale cached key here — same rule as change-password and
    // first-run creation.
    keyService.clearCache();
    final (newKey, newSalt) = await keyService.deriveNewKey(password);

    // Re-encrypt first. Only after it succeeds without throwing do we swap
    // the identity and the routing flags, so a mid-flight failure leaves the
    // boxes exactly as they were: fully unencrypted.
    await DatabaseService().enableEncryption(newKey);

    final verifier = keyService.computeVerifier(newKey);
    await secureStorage.savePasswordVerifier(base64Encode(verifier));
    await secureStorage.saveKdfSalt(base64Encode(newSalt));

    final db = DatabaseService();
    await db.setEncryptionChoice(true);
    await db.settingsBox.put('has_password', 'true');

    keyService.clearCache();

    if (!context.mounted) return;
    Navigator.of(progressContext).pop();

    await offerBiometricEnrollment(context, ref, newKey);

    if (!context.mounted) return;
    showAppSnack(
      context,
      t('encryption_enabled_success'),
      kind: SnackKind.success,
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(progressContext).pop();
    showErrorSnack(context, t('error_generic'), e);
  }
}

/// Blocking "do not close the app" progress dialog, mirroring the
/// change-password flow's structure verbatim.
BuildContext _showProgressDialog(BuildContext context, WidgetRef ref) {
  final t = ref.read(stringsProvider);
  showDialog<void>(
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
              t('enabling_encryption'),
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
  return context;
}