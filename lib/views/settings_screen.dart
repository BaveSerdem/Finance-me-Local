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
import '../localization/locale_provider.dart';
import 'customization_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('settings')), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _CustomizationTile(),
          const Divider(height: 32),
          _SectionHeader(title: t('language'), colorScheme: colorScheme),
          const _LanguageTile(),
          const Divider(height: 32),
          _SectionHeader(title: t('security_data'), colorScheme: colorScheme),
          _BiometricTile(),
          const SizedBox(height: 8),
          _ExportTile(),
          const SizedBox(height: 8),
          _ImportTile(),
          const Divider(height: 32),
          _SectionHeader(title: 'Danger Zone', colorScheme: colorScheme),
          const _DeleteAllDataTile(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colorScheme});

  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customization
// ---------------------------------------------------------------------------

class _CustomizationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(t('customization')),
        subtitle: Text(t('customization_subtitle')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomizationScreen()),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final t = ref.watch(stringsProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(t('language')),
        trailing: DropdownButton<String>(
          value: locale.languageCode,
          underline: const SizedBox(),
          items: [
            DropdownMenuItem(value: 'en', child: Text(t('english'))),
            const DropdownMenuItem(value: 'ar', child: Text('العربية')),
            const DropdownMenuItem(value: 'ru', child: Text('Русский')),
            const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
            const DropdownMenuItem(value: 'ku', child: Text('Kurdî')),
            const DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
          ],
          onChanged: (lang) {
            if (lang != null) {
              try {
                HapticFeedback.lightImpact();
                ref.read(localeProvider.notifier).setLocale(lang);
              } catch (_) {
              }
            }
          },
        ),
      ),
    );
  }
}

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

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    final ctx = context;
    final result = await showDialog<String>(
      context: ctx,
      builder: (ctx) {
        var isEmpty = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter Password'),
              content: TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Your app password'),
                onChanged: (value) {
                  final empty = value.isEmpty;
                  if (empty != isEmpty) {
                    setDialogState(() => isEmpty = empty);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isEmpty ? null : () => Navigator.pop(ctx, controller.text),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
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
        subtitle: Text(
          _biometricEnabled ? t('biometric_active') : t('biometric_off'),
        ),
        value: _biometricEnabled,
        onChanged: (value) async {
          HapticFeedback.lightImpact();
          final ctx = context;
          if (value) {
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Password verification not available. Please restart the app.')),
                  );
                }
                return;
              }

              final keyService = KeyService();
              final salt = base64Decode(saltB64);
              final derivedKey = await keyService.deriveKey(password, salt);
              final candidate = keyService.computeVerifier(derivedKey);
              final storedVerifier = base64Decode(verifierB64);

              if (!keyService.constantTimeEquals(candidate, storedVerifier)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Incorrect password')),
                  );
                }
                return;
              }

              final token = KeyService.computeBiometricToken(derivedKey);
              await storage.saveBiometricToken(token);
              await storage.saveBiometricKeyData(derivedKey);
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
// Export Backup
// ---------------------------------------------------------------------------

class _ExportTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.upload_file),
        label: Text(t('export_encrypted_backup')),
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showPasswordDialog(context, ref);
        },
      ),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.file_download),
        label: Text(t('import_encrypted_backup')),
        onPressed: () {
          HapticFeedback.mediumImpact();
          _startImport(context, ref);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared password dialog for export/import
// ---------------------------------------------------------------------------

void _showPasswordDialog(BuildContext context, WidgetRef ref) {
  final t = ref.read(stringsProvider);
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t('set_backup_password')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: t('password'),
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty ? t('password_required') : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                decoration: InputDecoration(
                  labelText: t('confirm_password'),
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) {
                  if (v != passwordController.text) {
                    return t('passwords_do_not_match');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop();
              await _exportBackup(context, passwordController.text, t);
            },
            child: Text(t('proceed')),
          ),
        ],
      );
    },
  );
}

Future<void> _exportBackup(
  BuildContext context,
  String password,
  String Function(String) t,
) async {
  final backupService = BackupService();
  final messenger = ScaffoldMessenger.of(context);

  try {
    final path = await backupService.exportData(password);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${t('backup_saved')} $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('invalid_backup_file')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  if (context.mounted) {
    _showImportPasswordDialog(context, ref, fileBytes);
  }
}

void _showImportPasswordDialog(
  BuildContext context,
  WidgetRef ref,
  Uint8List fileBytes,
) {
  final t = ref.read(stringsProvider);
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t('enter_backup_password')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: t('password'),
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) =>
                v == null || v.isEmpty ? t('password_required') : null,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop();
              await _importBackup(
                context,
                ref,
                passwordController.text,
                fileBytes,
                t,
              );
            },
            child: Text(t('proceed')),
          ),
        ],
      );
    },
  );
}

Future<void> _importBackup(
  BuildContext context,
  WidgetRef ref,
  String password,
  Uint8List fileBytes,
  String Function(String) t,
) async {
  final backupService = BackupService();
  final messenger = ScaffoldMessenger.of(context);

  try {
    final count = await backupService.importData(
      password,
      fileBytes: fileBytes,
    );
    ref.invalidate(transactionProvider);
    ref.invalidate(subscriptionProvider);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${t('imported')} $count ${t('imported_records')}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } on BackupDecryptionException {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('wrong_password_error')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } on BackupCorruptionException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.message.contains('Import cancelled')
                ? t('import_cancelled')
                : t('corrupt_backup_file'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

class _DeleteAllDataTileState extends ConsumerState<_DeleteAllDataTile> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    setState(() => _deleting = true);

    try {
      await SecureStorageService().clearAll();
      await DatabaseService().deleteAll();

      if (mounted) {
        ref.invalidate(transactionProvider);
        ref.invalidate(subscriptionProvider);
        SystemNavigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var isEmpty = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter Password'),
              content: TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Your app password',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final empty = v.isEmpty;
                  if (empty != isEmpty) {
                    setDialogState(() => isEmpty = empty);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isEmpty
                      ? null
                      : () => Navigator.pop(ctx, controller.text),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (password == null || password.isEmpty) return;

    final secureStorage = SecureStorageService();
    final verifierB64 = await secureStorage.getPasswordVerifier();
    final saltB64 = await secureStorage.getKdfSalt();

    if (verifierB64 == null || saltB64 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password verification not available. Please restart the app.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final keyService = KeyService();
    final salt = base64Decode(saltB64);
    final derivedKey = await keyService.deriveKey(password, salt);
    final candidate = keyService.computeVerifier(derivedKey);
    final storedVerifier = base64Decode(verifierB64);

    if (!keyService.constantTimeEquals(candidate, storedVerifier)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      _showConfirmationDialog();
    }
  }

  Future<void> _showConfirmationDialog() async {
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
                confirmController.text == 'DELETE';
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  const Text('Delete All Data'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will permanently erase all your transactions, '
                      'subscriptions, and settings. Encrypted data will be '
                      'unrecoverable.',
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
                      title: const Text('I understand this action cannot be undone'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: checkbox2,
                      onChanged: (v) =>
                          setDialogState(() => checkbox2 = v ?? false),
                      title: const Text('I take full responsibility'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      decoration: const InputDecoration(
                        hintText: 'Type DELETE to confirm',
                        border: OutlineInputBorder(),
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: canDelete
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Delete Everything'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.error.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(Icons.delete_forever, color: colorScheme.error),
        title: Text(
          'Delete All Data',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Erase all transactions, subscriptions, and settings',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.error),
        onTap: _deleting ? null : _showPasswordDialog,
      ),
    );
  }
}
