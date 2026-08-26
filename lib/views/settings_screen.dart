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
import '../providers/theme_provider.dart';
import '../theme/app_metrics.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_snack.dart';
import '../widgets/settings_tiles.dart';
import 'customization_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);

    return AppScaffold(
      title: t('settings'),
      // Three destinations, no section headers.
      //
      // Each header here named exactly one card, and named it with the same
      // words the card already carried — "Language" above a tile titled
      // "Language". A header's job is to name a *group*; when the group holds
      // one item of the same name it adds a line of text and nothing else.
      // The first card had no header at all, so the screen was also asymmetric.
      //
      // Dividers go with them: three cards separated by their own margins read
      // as a list already.
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        children: const [
          _CustomizationTile(),
          _LanguageTile(),
          _SecurityTile(),
        ],
      ),
    );
  }
}

class _CustomizationTile extends ConsumerWidget {
  const _CustomizationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return SettingsTile(
      icon: Icons.palette_outlined,
      title: t('customization'),
      subtitle: t('customization_subtitle'),
      hapticsEnabled: !reduceAnimations,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustomizationScreen()),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final t = ref.watch(stringsProvider);
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return SettingsChoiceTile<String>(
      icon: Icons.language,
      title: t('language'),
      value: locale.languageCode,
      // Derived from `supportedLanguages` rather than a second hardcoded list,
      // so adding a language is a one-line change in one file.
      options: [
        for (final entry in supportedLanguages.entries) (entry.key, entry.value),
      ],
      hapticsEnabled: !reduceAnimations,
      onChanged: (lang) async {
        try {
          await ref.read(localeProvider.notifier).setLocale(lang);
        } catch (e) {
          // The original swallowed this in an empty `catch (_) {}`, so a failed
          // language change looked identical to a successful one.
          if (context.mounted) {
            showErrorSnack(context, t('error_generic'), e);
          }
        }
      },
    );
  }
}

class _SecurityTile extends ConsumerWidget {
  const _SecurityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return SettingsTile(
      icon: Icons.security_outlined,
      title: t('security_privacy'),
      subtitle: t('security_privacy_subtitle'),
      hapticsEnabled: !reduceAnimations,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SecurityScreen()),
      ),
    );
  }
}
