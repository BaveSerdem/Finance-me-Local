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

/// A raised surface holding grouped content.
///
/// Replaces the hand-built `Container` + `BoxDecoration` blocks that each
/// re-declared their own radius, fill and shadow.
///
/// Depth comes from **surface tone plus a hairline border**, not from a
/// `BoxShadow`. That is deliberate: a shadow needs something to fall on, so it
/// disappears entirely in AMOLED mode where the background is pure black, and
/// it muddies the user's custom background tint. A tonal step reads correctly
/// on every one of those grounds.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(AppSpace.xl),
  });

  final Widget child;

  /// Optional heading rendered above [child].
  final String? title;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.hairline),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                child,
              ],
            ),
    );
  }
}
