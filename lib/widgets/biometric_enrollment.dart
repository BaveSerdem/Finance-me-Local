// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';
import '../services/biometric_service.dart';
import '../services/key_service.dart';
import '../services/secure_storage_service.dart';

/// Offers to enable fingerprint unlock after a password has been set up.
///
/// Shared by the first-run password screen and the enable-encryption-later
/// flow. Shows an explanatory dialog first (never fires the system biometric
/// prompt without context) and only enrolls when the user accepts. Enrollment
/// is best-effort: any failure is silent and the user still reaches home —
/// biometrics can always be enabled later in Settings.
Future<void> offerBiometricEnrollment(
  BuildContext context,
  WidgetRef ref,
  Uint8List key,
) async {
  final t = ref.read(stringsProvider);
  if (!context.mounted) return;

  final enable = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('enable_biometric_title')),
      content: Text(t('enable_biometric_explanation')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(t('enable_biometric_ok')),
        ),
      ],
    ),
  );

  if (enable != true || !context.mounted) return;

  try {
    final storage = SecureStorageService();
    final biometric = BiometricService(secureStorage: storage);
    if (!await biometric.isBiometricAvailable()) return;

    final authenticated = await biometric.authenticate();
    if (!authenticated) return;

    await biometric.setBiometricLoginEnabled(true);
    await storage.saveBiometricToken(KeyService.computeBiometricToken(key));
    await storage.saveBiometricKeyData(key);
  } catch (_) {
    // Best-effort; never block entering the app on biometric enrollment.
  }
}