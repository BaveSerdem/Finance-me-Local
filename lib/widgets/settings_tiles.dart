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

import '../theme/app_icons.dart';
import '../theme/app_metrics.dart';

/// A settings row that opens another screen.
///
/// Replaces the `Card` + `ListTile(leading:, title:, subtitle:, trailing:
/// Icon(chevron_right), onTap:)` block repeated across Settings and Security,
/// each of which re-declared the same chevron and its own haptic call.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.hapticsEnabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Pass the negation of `reduceAnimations`. Once that setting becomes
  /// reachable, every tile honours it from one place.
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(AppIcons.forward),
        onTap: () {
          if (hapticsEnabled) HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }
}

/// A settings row carrying an on/off switch.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.hapticsEnabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: (next) {
          if (hapticsEnabled) HapticFeedback.lightImpact();
          onChanged(next);
        },
      ),
    );
  }
}

/// A settings row offering a choice.
///
/// The choice opens a bottom sheet rather than a `DropdownButton` sitting in
/// `ListTile.trailing`. That arrangement gave the dropdown whatever width the
/// title left over, so sixteen currency codes — or a language endonym at the
/// 1.15x font setting — overflowed the row. A sheet also gives each option a
/// full-width, 48dp-tall target instead of a cramped popup list, and shows the
/// current selection with a check rather than only by position.
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hapticsEnabled = true,
  });

  final IconData icon;
  final String title;
  final T value;

  /// Option value paired with the label to show for it.
  final List<(T, String)> options;

  final ValueChanged<T> onChanged;
  final bool hapticsEnabled;

  String get _currentLabel {
    for (final (optionValue, label) in options) {
      if (optionValue == value) return label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(_currentLabel),
        trailing: const Icon(AppIcons.forward),
        onTap: () => _openSheet(context),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    if (hapticsEnabled) HapticFeedback.lightImpact();

    final chosen = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.sm,
                AppSpace.xl,
                AppSpace.md,
              ),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (optionValue, label) in options)
                    ListTile(
                      title: Text(label),
                      trailing: optionValue == value
                          ? Icon(
                              Icons.check,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            )
                          : null,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(optionValue),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );

    if (chosen != null && chosen != value) onChanged(chosen);
  }
}
