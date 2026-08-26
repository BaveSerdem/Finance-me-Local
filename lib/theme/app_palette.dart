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

/// Semantic colour layer for the whole app.
///
/// Every surface and ink token here is an **alias onto the [ColorScheme]** that
/// `buildThemeData` already builds. That is deliberate: `AppBar`, `Card`,
/// `Dialog`, `TextField` and `DatePicker` all paint from the scheme, so any
/// token that re-authored its own hex would drift out of step with them — which
/// is exactly the defect this layer exists to remove.
///
/// Only [income] and [expense] are authored independently, because Material has
/// no semantic slot for "money in" and "money out".
///
/// Because the scheme already accounts for brightness, AMOLED and the user's
/// accent, every one of those settings flows through here for free.
///
/// Colour never carries meaning alone: when [distinguishByForm] is true the
/// income/expense pair switches to a colourblind-safe blue/orange, and widgets
/// must additionally encode meaning through sign, position or shape.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.income,
    required this.incomeWash,
    required this.expense,
    required this.expenseWash,
    required this.warning,
    required this.caution,
    required this.accent,
    required this.accentWash,
    required this.onAccent,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceWell,
    required this.hairline,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkFaint,
    required this.distinguishByForm,
  });

  /// Money coming in.
  final Color income;

  /// Low-opacity [income], for fills behind text and chart bars.
  final Color incomeWash;

  /// Money going out.
  final Color expense;

  /// Low-opacity [expense], for fills behind text and chart bars.
  final Color expenseWash;

  /// Poor-but-not-invalid. Material's scheme has `error` for "wrong" and
  /// nothing between that and "fine", so a severity ramp — the password
  /// strength meter — had to hand-author its middle steps. Authored here for
  /// the same reason [income] and [expense] are: no semantic slot exists.
  ///
  /// Both are darkened in light mode; the raw orange and amber they replace
  /// were picked against a dark background and dropped to roughly 2:1 on a
  /// white one.
  final Color warning;

  /// Acceptable, short of good — the step above [warning].
  final Color caution;

  /// The user's chosen accent. Reserved for "active" and "selected" states —
  /// never reused for income or expense, or the two meanings collide.
  final Color accent;

  /// Low-opacity [accent], for selected chips and segmented controls.
  final Color accentWash;

  /// Text and icons drawn on top of [accent].
  final Color onAccent;

  /// The screen background.
  final Color surfaceBase;

  /// Cards and sheets — one tonal step off [surfaceBase].
  final Color surfaceRaised;

  /// Two steps off [surfaceBase] — meter tracks, inactive segments, the resting
  /// state of a control that sits inside a card.
  ///
  /// Named a *well* rather than "sunken" because Material 3 has no sunken
  /// direction: its container ramp runs `Lowest → Highest` away from the base
  /// in **one** direction, and that direction flips between light and dark. The
  /// previous version took `surfaceContainerLowest` for this and
  /// `surfaceContainer` for [surfaceRaised] — opposite ends of the same ramp —
  /// so in light mode the "well" came out *brighter* than the page while the
  /// "raised" card came out darker. Two adjacent rows on the Overview read as
  /// inverted, which is exactly what the first device screenshot showed.
  ///
  /// Both tokens now step the same way, so their relationship holds in either
  /// brightness.
  final Color surfaceWell;

  /// Dividers and card borders.
  final Color hairline;

  /// Primary reading text.
  final Color inkPrimary;

  /// Supporting text — captions and metadata.
  final Color inkSecondary;

  /// De-emphasised text — axis labels, disabled states.
  final Color inkFaint;

  /// True in colourblind mode. Widgets must add a non-colour cue: an explicit
  /// sign, an icon, or a position change.
  final bool distinguishByForm;

  /// Derives the palette from the theme's own [ColorScheme].
  ///
  /// [colourblind] comes from `ThemeSettings.colorPalette == 'colorblind_safe'`.
  factory AppPalette.fromScheme(
    ColorScheme scheme, {
    required bool colourblind,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    // Green/red is the worst possible pair for red-green colourblindness, which
    // is exactly the pair income/expense needs. Blue/orange stays separable
    // under all three common types.
    final Color income;
    final Color expense;
    if (colourblind) {
      income = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      expense = isDark ? const Color(0xFFFFA726) : const Color(0xFFE65100);
    } else {
      income = isDark ? const Color(0xFF4C9E6E) : const Color(0xFF2E7D50);
      expense = isDark ? const Color(0xFFC85C5C) : const Color(0xFFB03B3B);
    }

    final washAlpha = isDark ? 0.16 : 0.11;

    return AppPalette(
      income: income,
      incomeWash: income.withValues(alpha: washAlpha),
      expense: expense,
      expenseWash: expense.withValues(alpha: washAlpha),
      warning: isDark ? const Color(0xFFE08A3C) : const Color(0xFF9C5511),
      caution: isDark ? const Color(0xFFD9B44A) : const Color(0xFF7A6114),
      accent: scheme.primary,
      accentWash: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
      onAccent: scheme.onPrimary,
      surfaceBase: scheme.surface,
      surfaceRaised: scheme.surfaceContainerLow,
      surfaceWell: scheme.surfaceContainerHigh,
      hairline: scheme.outlineVariant,
      inkPrimary: scheme.onSurface,
      inkSecondary: scheme.onSurfaceVariant,
      inkFaint: scheme.outline,
      distinguishByForm: colourblind,
    );
  }

  /// The colour representing an amount of the given direction.
  Color amountColor({required bool isExpense}) => isExpense ? expense : income;

  /// The wash representing an amount of the given direction.
  Color amountWash({required bool isExpense}) =>
      isExpense ? expenseWash : incomeWash;

  @override
  AppPalette copyWith({
    Color? income,
    Color? incomeWash,
    Color? expense,
    Color? expenseWash,
    Color? warning,
    Color? caution,
    Color? accent,
    Color? accentWash,
    Color? onAccent,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceWell,
    Color? hairline,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkFaint,
    bool? distinguishByForm,
  }) {
    return AppPalette(
      income: income ?? this.income,
      incomeWash: incomeWash ?? this.incomeWash,
      expense: expense ?? this.expense,
      expenseWash: expenseWash ?? this.expenseWash,
      warning: warning ?? this.warning,
      caution: caution ?? this.caution,
      accent: accent ?? this.accent,
      accentWash: accentWash ?? this.accentWash,
      onAccent: onAccent ?? this.onAccent,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceWell: surfaceWell ?? this.surfaceWell,
      hairline: hairline ?? this.hairline,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkFaint: inkFaint ?? this.inkFaint,
      distinguishByForm: distinguishByForm ?? this.distinguishByForm,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      income: Color.lerp(income, other.income, t)!,
      incomeWash: Color.lerp(incomeWash, other.incomeWash, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseWash: Color.lerp(expenseWash, other.expenseWash, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentWash: Color.lerp(accentWash, other.accentWash, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceWell: Color.lerp(surfaceWell, other.surfaceWell, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      distinguishByForm: t < 0.5 ? distinguishByForm : other.distinguishByForm,
    );
  }
}

/// Black or white, whichever stays readable on [background].
///
/// Used wherever a colour is chosen at runtime and something must be drawn on
/// top of it — the accent swatches, for instance, whose selection tick was
/// hardcoded to black and so vanished on the darker swatches.
Color readableOn(Color background) => background.computeLuminance() > 0.5
    ? const Color(0xFF16181C)
    : const Color(0xFFFFFFFF);

/// Reads the palette.
///
/// Falls back to deriving one on the spot rather than throwing: a `showDialog`
/// or `DatePicker` wrapped in a local `Theme` that forgot to carry `extensions`
/// would otherwise crash the screen instead of merely looking slightly off.
extension AppPaletteAccess on BuildContext {
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        AppPalette.fromScheme(theme.colorScheme, colourblind: false);
  }
}
