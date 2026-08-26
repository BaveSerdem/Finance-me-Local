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

import '../theme/app_metrics.dart';

/// Label above a group of rows.
///
/// Replaces four separate `_SectionHeader` classes. The Settings and Security
/// copies were character-for-character identical; Customization differed only
/// in reading the colour scheme itself rather than being handed it; Home added
/// a leading icon and used its own padding and weight. One optional [icon]
/// covers all four.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color,
  });

  final String title;

  /// Optional leading glyph, used where a section needs a second channel
  /// besides its label.
  final IconData? icon;

  /// Defaults to the user's accent. Pass a semantic colour where the section
  /// itself carries meaning — income or expense, say.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = color ?? theme.colorScheme.primary;

    final label = Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: resolved,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.md),
      child: icon == null
          ? label
          : Row(
              children: [
                Icon(icon, size: 18, color: resolved),
                const SizedBox(width: AppSpace.sm),
                label,
              ],
            ),
    );
  }
}
