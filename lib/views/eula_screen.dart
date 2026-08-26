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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';
import '../services/secure_storage_service.dart';

class EulaScreen extends ConsumerStatefulWidget {
  final VoidCallback? onAccepted;

  const EulaScreen({super.key, this.onAccepted});

  @override
  ConsumerState<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends ConsumerState<EulaScreen> {
  Future<void> _onAccept() async {
    await SecureStorageService().setEulaAccepted(true);
    if (!mounted) return;
    if (widget.onAccepted != null) {
      widget.onAccepted!();
    }
  }

  void _onDecline() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
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
              SizedBox(
                width: 72,
                height: 72,
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
                t('terms_of_use'),
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
                          t('eula_intro'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          theme,
                          t('eula_local_title'),
                          t('eula_local_body'),
                        ),
                        _buildSection(
                          theme,
                          t('eula_advisor_title'),
                          t('eula_advisor_body'),
                        ),
                        _buildSection(
                          theme,
                          t('eula_liability_title'),
                          t('eula_liability_body'),
                        ),
                        _buildSection(
                          theme,
                          t('eula_responsibility_title'),
                          t('eula_responsibility_body'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onAccept,
                  child: Text(t('i_agree')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onDecline,
                  child: Text(t('decline')),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String body) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
