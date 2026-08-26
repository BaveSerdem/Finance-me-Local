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
import '../theme/app_palette.dart';

/// Placeholder shown where a list or chart has nothing to display.
///
/// Replaces three near-identical implementations — `_EmptyState` on Home,
/// `_EmptyAnalytics` on Analytics, and an inline copy in the Recurring screen —
/// which shared the same 80px icon, title and hint but disagreed on padding and
/// on whether a hint appeared at all.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final String label;

  /// Optional second line explaining how to fill the emptiness.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Center(
      child: Padding(
        // Was `vertical: 80` on top of a `SliverFillRemaining` that already
        // centres its child — the two stacked into the dead band visible under
        // the header on an empty month.
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.xxl,
          horizontal: AppSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `hairline` is `outlineVariant` — correct for a 1px rule, far too
            // faint for an 80px glyph, which rendered as an almost invisible
            // smudge. A smaller mark in `inkFaint` reads as intentional.
            Icon(icon, size: 56, color: palette.inkFaint),
            const SizedBox(height: AppSpace.lg),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
