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

import '../theme/app_palette.dart';

/// Where an amount sits in the hierarchy.
///
/// Sizes come from the theme's `textTheme`, not from literal numbers. Every
/// amount in the app previously carried a raw `fontSize:` — 48, 22, 16, 15, 12
/// — which meant the user's font-size setting (0.85 / 1.0 / 1.15) scaled the
/// rest of the interface while **money stayed fixed**. Reading through the
/// theme fixes that everywhere at once.
enum MoneySize {
  /// The one headline figure on a screen — the balance.
  hero,

  /// A section total.
  title,

  /// A list row.
  row,

  /// Chart labels and secondary figures.
  caption,
}

/// What an amount means.
enum MoneyTone {
  /// Not directional — a balance, a category total.
  neutral,

  /// Money in.
  income,

  /// Money out.
  expense,
}

/// Renders a money amount.
///
/// Takes the **already formatted** string, so the caller decides between
/// `MoneyFormat.amount`, `.signed` and `.compact`. Keeping the formatting out
/// of the widget is what lets a transaction row show an explicit `+`/`-` from
/// its unsigned stored magnitude while a balance shows a sign only when it is
/// genuinely negative.
///
/// Replaces eleven separate `TextStyle`s that each repeated
/// `fontFeatures: [FontFeature.tabularFigures()]` at four different sizes.
/// Tabular figures matter here: without them digits have unequal widths and
/// amounts in a column fail to line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.text, {
    super.key,
    this.size = MoneySize.row,
    this.tone = MoneyTone.neutral,
    this.color,
  });

  /// Output of a `MoneyFormat` method.
  final String text;

  final MoneySize size;

  final MoneyTone tone;

  /// Overrides the colour [tone] would choose. Used where a chart already owns
  /// its series colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final base = switch (size) {
      MoneySize.hero => theme.textTheme.displayMedium,
      MoneySize.title => theme.textTheme.titleLarge,
      MoneySize.row => theme.textTheme.titleMedium,
      MoneySize.caption => theme.textTheme.bodySmall,
    };

    final weight = switch (size) {
      MoneySize.hero => FontWeight.bold,
      MoneySize.title => FontWeight.w800,
      MoneySize.row => FontWeight.w700,
      MoneySize.caption => FontWeight.w600,
    };

    final resolved = color ??
        switch (tone) {
          MoneyTone.neutral => palette.inkPrimary,
          MoneyTone.income => palette.income,
          MoneyTone.expense => palette.expense,
        };

    return Text(
      _withFormCue(text, palette.distinguishByForm),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base?.copyWith(
        fontWeight: weight,
        color: resolved,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// In colourblind mode, direction must be readable without hue.
  ///
  /// `MoneyFormat.signed` already emits an explicit `+`/`-`, so rows are
  /// covered. Totals rendered through `MoneyFormat.amount` are not — a positive
  /// income total prints bare. This adds the missing `+` for those, and never
  /// doubles a sign that is already present.
  String _withFormCue(String value, bool distinguishByForm) {
    if (!distinguishByForm) return value;
    if (tone == MoneyTone.neutral) return value;
    if (value.startsWith('-') || value.startsWith('+')) return value;
    return tone == MoneyTone.expense ? '-$value' : '+$value';
  }
}
