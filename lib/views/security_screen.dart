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
import 'package:file_picker/file_picker.dart';
import '../providers/transaction_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/key_service.dart';
import '../services/secure_storage_service.dart';
import '../services/database_service.dart';
import '../services/app_reset_service.dart';
import '../localization/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_metrics.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/section_header.dart';
import '../widgets/app_snack.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/change_password_flow.dart';
import '../widgets/enable_encryption_flow.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    // When encryption is off there is no password and no biometric unlock, so
    // those two sections have no meaning; only the Danger Zone remains.
    final encryptionOff = DatabaseService().getEncryptionChoice() == false;
    return AppScaffold(
      title: t("security_privacy"),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Unencrypted branch: no password and no encrypted biometric unlock,
          // so the Authentication/Password sections have no meaning here.
          // Instead this branch owns the path to enabling encryption later.
          if (!encryptionOff) ...[
            SectionHeader(title: t('authentication')),
            _BiometricTile(),
            const Divider(height: 32),
            SectionHeader(title: t('password')),
            const _ChangePasswordTile(),
            const Divider(height: 32),
          ] else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.enhanced_encryption_outlined),
                title: Text(t('enable_encryption_now_title')),
                subtitle: Text(t('enable_encryption_now_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showEnableEncryptionFlow(context, ref),
              ),
            ),
          ],
          // The one header on this screen that names a real group of three, and
          // the only one that should escalate: its cards can destroy data, so
          // it carries the error colour rather than the neutral accent every
          // other header uses.
          SectionHeader(
            title: t('danger_zone'),
            color: Theme.of(context).colorScheme.error,
          ),
          // No `SizedBox` between these. `cardTheme.margin` already puts
          // `AppSpace.sm` under every card, so the explicit gaps doubled it and
          // made this group sit looser than every other list in the app.
          _ExportTile(),
          _ImportTile(),
          const _DeleteAllDataTile(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Biometric Lock
// ---------------------------------------------------------------------------

class _BiometricTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  final _biometricService = BiometricService(
    secureStorage: SecureStorageService(),
  );
  bool _biometricEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await _biometricService.isBiometricLoginEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _loading = false;
      });
    }
  }

  Future<String?> _promptForPassword() {
    final t = ref.read(stringsProvider);
    return showPasswordPromptDialog(
      context,
      title: t('enter_password'),
      label: t('your_app_password'),
      confirmLabel: t('confirm'),
      cancelLabel: t('cancel'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    if (_loading) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(t('biometric_lock')),
          trailing: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.fingerprint),
        title: Text(t('biometric_lock')),
        // Was "Biometric lock is off" — a sentence restating the switch beside
        // it. A subtitle should say what the control *does*, since the switch
        // already says what state it is in.
        subtitle: Text(t('biometric_lock_subtitle')),
        value: _biometricEnabled,
        onChanged: (value) async {
          HapticFeedback.lightImpact();
          final ctx = context;
          if (value) {
            try {
              final storage = SecureStorageService();
              final savedToken = await storage.getBiometricToken();
              if (savedToken == null) {
                if (!mounted) return;
                final password = await _promptForPassword();
                if (password == null || password.isEmpty || !mounted) return;

                final secureStorage = SecureStorageService();
                final verifierB64 = await secureStorage.getPasswordVerifier();
                final saltB64 = await secureStorage.getKdfSalt();

                if (verifierB64 == null || saltB64 == null) {
                  if (context.mounted) {
                    showAppSnack(
                      ctx,
                      t('password_verify_unavailable'),
                      kind: SnackKind.error,
                    );
                  }
                  return;
                }

                final keyService = KeyService();
                keyService.clearCache();
                final salt = base64Decode(saltB64);
                final derivedKey = await keyService.deriveKey(password, salt);
                final candidate = keyService.computeVerifier(derivedKey);
                final storedVerifier = base64Decode(verifierB64);

                if (!keyService.constantTimeEquals(candidate, storedVerifier)) {
                  if (context.mounted) {
                    showAppSnack(
                      ctx,
                      t('incorrect_password'),
                      kind: SnackKind.error,
                    );
                  }
                  return;
                }

                final token = KeyService.computeBiometricToken(derivedKey);
                await storage.saveBiometricToken(token);
                await storage.saveBiometricKeyData(derivedKey);
              }
            } catch (e) {
              if (context.mounted) {
                showErrorSnack(ctx, t('failed_enable_biometric'), e);
              }
              return;
            }
          }
          await _biometricService.setBiometricLoginEnabled(value);
          setState(() => _biometricEnabled = value);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change Password
// ---------------------------------------------------------------------------

class _ChangePasswordTile extends ConsumerWidget {
  const _ChangePasswordTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_reset_outlined),
        title: Text(t('change_password')),
        subtitle: Text(t('change_password_subtitle')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showChangePasswordFlow(context, ref),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export Backup
// ---------------------------------------------------------------------------

/// Backup export.
///
/// Was a bare full-width `OutlinedButton` sitting between cards, so two of the
/// five rows in this screen spoke a different visual language from the rest.
/// `SettingsTile` is the language everything else here uses.
class _ExportTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    return SettingsTile(
      icon: Icons.upload_file,
      title: t('export_encrypted_backup'),
      // These two carried no subtitle while the third card in the same group
      // did, so the group read as two short rows and one tall one.
      subtitle: t('export_backup_subtitle'),
      hapticsEnabled: !reduceMotion,
      onTap: () => _showPasswordDialog(context, ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Import Backup
// ---------------------------------------------------------------------------

class _ImportTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    return SettingsTile(
      icon: Icons.file_download,
      title: t('import_encrypted_backup'),
      subtitle: t('import_backup_subtitle'),
      hapticsEnabled: !reduceMotion,
      onTap: () => _startImport(context, ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared password dialog for export/import
// ---------------------------------------------------------------------------

Future<void> _showPasswordDialog(BuildContext context, WidgetRef ref) async {
  final t = ref.read(stringsProvider);

  final password = await showNewPasswordDialog(
    context,
    title: t('set_backup_password'),
    passwordLabel: t('password'),
    confirmLabel: t('confirm_password'),
    submitLabel: t('proceed'),
    cancelLabel: t('cancel'),
    requiredMessage: t('password_required'),
    mismatchMessage: t('passwords_do_not_match'),
    minLength: 6,
    tooShortMessage: t('password_too_short'),
  );

  if (password == null || !context.mounted) return;

  try {
    await _exportBackup(context, ref, password);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, t('export_failed'), e);
  }
}

Future<void> _exportBackup(
  BuildContext context,
  WidgetRef ref,
  String password,
) async {
  final t = ref.read(stringsProvider);
  final tf = ref.read(stringsFormatProvider);
  final backupService = BackupService();

  try {
    final path = await backupService.exportData(password);
    if (context.mounted) {
      showAppSnack(
        context,
        tf('backup_saved_at', {'path': path}),
        kind: SnackKind.success,
      );
    }
  } catch (e) {
    if (context.mounted) showErrorSnack(context, t('export_failed'), e);
  }
}

Future<void> _startImport(BuildContext context, WidgetRef ref) async {
  final t = ref.read(stringsProvider);
  final result = await FilePicker.pickFiles(
    dialogTitle: t('select_encrypted_backup'),
    type: FileType.any,
    allowMultiple: false,
    withData: true,
  );

  if (result == null || result.files.isEmpty) return;

  final fileBytes = result.files.first.bytes;
  if (fileBytes == null || fileBytes.length < 33) {
    if (context.mounted) {
      showAppSnack(context, t('invalid_backup_file'), kind: SnackKind.error);
    }
    return;
  }

  if (context.mounted) {
    _showImportPasswordDialog(context, ref, fileBytes);
  }
}

Future<void> _showImportPasswordDialog(
  BuildContext context,
  WidgetRef ref,
  Uint8List fileBytes,
) async {
  final t = ref.read(stringsProvider);

  final password = await showPasswordPromptDialog(
    context,
    title: t('enter_backup_password'),
    label: t('password'),
    confirmLabel: t('proceed'),
    cancelLabel: t('cancel'),
  );

  if (password == null || !context.mounted) return;

  try {
    await _importBackup(context, ref, password, fileBytes);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, t('import_failed'), e);
  }
}

Future<void> _importBackup(
  BuildContext context,
  WidgetRef ref,
  String password,
  Uint8List fileBytes,
) async {
  final t = ref.read(stringsProvider);
  final tf = ref.read(stringsFormatProvider);
  final backupService = BackupService();

  try {
    final count = await backupService.importData(
      password,
      fileBytes: fileBytes,
    );
    ref.invalidate(transactionProvider);
    ref.invalidate(subscriptionProvider);
    if (context.mounted) {
      showAppSnack(
        context,
        tf('imported_count', {'count': '$count'}),
        kind: SnackKind.success,
      );
    }
  } on BackupDecryptionException {
    if (context.mounted) {
      showAppSnack(context, t('wrong_password_error'), kind: SnackKind.error);
    }
  } on BackupCorruptionException catch (e) {
    if (context.mounted) {
      showAppSnack(
        context,
        e.message.contains('Import cancelled')
            ? t('import_cancelled')
            : t('corrupt_backup_file'),
        kind: SnackKind.error,
      );
    }
  } catch (e) {
    if (context.mounted) showErrorSnack(context, t('import_failed'), e);
  }
}

// ---------------------------------------------------------------------------
// Delete All Data
// ---------------------------------------------------------------------------

class _DeleteAllDataTile extends ConsumerStatefulWidget {
  const _DeleteAllDataTile();

  @override
  ConsumerState<_DeleteAllDataTile> createState() =>
      _DeleteAllDataTileState();
}

/// The word the user must type to arm the wipe.
///
/// Deliberately **not** translated. It is a typed literal compared byte for
/// byte, so translating it would mean the comparison and the hint could drift
/// apart in five languages at once; the hint carries it as a `{word}` slot
/// instead, which keeps the sentence translatable and the token fixed.
const String _confirmationWord = 'DELETE';

class _DeleteAllDataTileState extends ConsumerState<_DeleteAllDataTile> {
  bool _deleting = false;

  // Delete-all demands a password only when one exists (i.e. encryption is on).
  // With encryption off there is no password and no verifier, so a guarded
  // wipe would dead-end at "password unavailable" and never let the user reach
  // the confirmation dialog. Pass an explicit "no password" shortcut instead.
  void _startDelete() {
    if (DatabaseService().getEncryptionChoice() == false) {
      _showConfirmationDialog();
    } else {
      _showPasswordDialog();
    }
  }

  Future<void> _confirmDelete() async {
    final tf = ref.read(stringsFormatProvider);
    setState(() => _deleting = true);

    try {
      // The OS clears the entire app data directory and kills the process, so
      // no per-box/per-key manual deletion is needed here. If the call
      // succeeds the process dies shortly after — code below will likely not
      // execute, which is expected. Only a PlatformException means the wipe
      // didn't start and the user must be told.
      await AppResetService.clearAllAppData();
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tf('delete_all_failed', {'message': e.message ?? ''}),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showPasswordDialog() async {
    final t = ref.read(stringsProvider);

    final password = await showPasswordPromptDialog(
      context,
      title: t('enter_password'),
      label: t('your_app_password'),
      confirmLabel: t('confirm'),
      cancelLabel: t('cancel'),
    );

    if (password == null || password.isEmpty) return;

    final secureStorage = SecureStorageService();
    final verifierB64 = await secureStorage.getPasswordVerifier();
    final saltB64 = await secureStorage.getKdfSalt();

    if (verifierB64 == null || saltB64 == null) {
      if (mounted) {
        showAppSnack(
          context,
          t('password_verify_unavailable'),
          kind: SnackKind.error,
        );
      }
      return;
    }

    final keyService = KeyService();
    keyService.clearCache();
    final salt = base64Decode(saltB64);
    final derivedKey = await keyService.deriveKey(password, salt);
    final candidate = keyService.computeVerifier(derivedKey);
    final storedVerifier = base64Decode(verifierB64);

    if (!keyService.constantTimeEquals(candidate, storedVerifier)) {
      if (mounted) {
        showAppSnack(context, t('incorrect_password'), kind: SnackKind.error);
      }
      return;
    }

    if (mounted) {
      _showConfirmationDialog();
    }
  }

  Future<void> _showConfirmationDialog() async {
    final t = ref.read(stringsProvider);
    final tf = ref.read(stringsFormatProvider);
    bool checkbox1 = false;
    bool checkbox2 = false;
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = checkbox1 &&
                checkbox2 &&
                confirmController.text == _confirmationWord;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(t('delete_all_data'))),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('delete_all_warning'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: checkbox1,
                      onChanged: (v) =>
                          setDialogState(() => checkbox1 = v ?? false),
                      title: Text(t('delete_all_ack_undone')),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: checkbox2,
                      onChanged: (v) =>
                          setDialogState(() => checkbox2 = v ?? false),
                      title: Text(t('delete_all_ack_responsibility')),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      decoration: InputDecoration(
                        hintText: tf('delete_all_type_confirm', {
                          'word': _confirmationWord,
                        }),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t('cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: canDelete
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: Text(t('delete_everything')),
                ),
              ],
            );
          },
        );
      },
    );

    confirmController.dispose();

    if (confirmed == true) {
      await _confirmDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer.withAlpha(60),
      // Radius from the scale, not a literal 12 — this was the one card in the
      // app with its own corner.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colorScheme.error.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(Icons.delete_forever, color: colorScheme.error),
        title: Text(
          t('delete_all_data'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          t('delete_all_data_subtitle'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(AppIcons.forward, color: colorScheme.error),
        onTap: _deleting ? null : _startDelete,
      ),
    );
  }
}
