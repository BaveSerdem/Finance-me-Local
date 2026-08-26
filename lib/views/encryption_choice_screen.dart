// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';
import '../services/database_service.dart';

/// Asks a first-time user whether they want their data encrypted.
///
/// Lives between the EULA and password creation in the first-run chain: shown
/// only when `DatabaseService().getEncryptionChoice()` is null (never decided).
/// Choosing to encrypt persists the choice and proceeds to password creation;
/// opting out persists the choice and skips encryption/password entirely.
class EncryptionChoiceScreen extends ConsumerWidget {
  final VoidCallback onEncryptionEnabled;
  final VoidCallback onSkipped;

  const EncryptionChoiceScreen({
    super.key,
    required this.onEncryptionEnabled,
    required this.onSkipped,
  });

  Future<void> _enable(BuildContext context) async {
    await DatabaseService().setEncryptionChoice(true);
    if (!context.mounted) return;
    onEncryptionEnabled();
  }

  Future<void> _skip(BuildContext context) async {
    await DatabaseService().setEncryptionChoice(false);
    if (!context.mounted) return;
    onSkipped();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLarge = MediaQuery.of(context).size.height > 700;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(30),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset('img/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Text(
                'Finance me Local',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('encryption_choice_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: isLarge ? 5 : 4,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(120),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('encryption_choice_description'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          theme,
                          t('encryption_choice_on_body'),
                        ),
                        const SizedBox(height: 12),
                        _buildSection(
                          theme,
                          t('encryption_choice_off_body'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => _enable(context),
                  child: Text(t('encryption_choice_enable')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _skip(context),
                  child: Text(t('encryption_choice_skip')),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String body) {
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}