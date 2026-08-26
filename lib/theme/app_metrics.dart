// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

/// Layout constants for the whole app.
///
/// The point of a scale is that **distance encodes relationship**: 8 inside a
/// row, 16 between rows, 24 between groups, 32 between sections. Before this
/// file there were 91 `SizedBox` gaps spread across 12 arbitrary values, so
/// nothing visually grouped with anything.
///
/// Every layout built on these must survive the user's font-size setting
/// (0.85–1.15x), so these are *gaps and radii only* — never fixed heights for
/// anything containing text.
library;

/// Spacing scale. A 4-step ramp covers 91% of the app's existing gaps.
abstract final class AppSpace {
  /// 4 — hairline separation inside a compound label.
  static const double xs = 4;

  /// 8 — between elements inside one row or card.
  static const double sm = 8;

  /// 12 — between a leading icon and its text.
  static const double md = 12;

  /// 16 — between sibling rows; the default screen inset.
  static const double lg = 16;

  /// 24 — between groups of rows.
  static const double xl = 24;

  /// 32 — between major sections.
  static const double xxl = 32;
}

/// Corner radii, one per role. Before this there were six competing values, so
/// two adjacent items in the same list had different corners.
abstract final class AppRadius {
  /// 8 — indicators, meter tracks, small chips.
  static const double sm = 8;

  /// 16 — list rows, inputs, day counters.
  static const double md = 16;

  /// 24 — cards and dialogs.
  static const double lg = 24;

  /// 32 — bottom sheets.
  static const double xl = 32;
}

/// Minimum interactive sizes.
abstract final class AppTap {
  /// 48 — the Material minimum touch target. Anything tappable must reach this,
  /// even when its visible glyph is smaller.
  static const double min = 48;
}

/// Animation durations, in milliseconds.
///
/// All of these must be gated on `reduceAnimations` (or
/// `MediaQuery.disableAnimationsOf`) at the call site.
abstract final class AppMotion {
  /// 120ms — state changes on a control the finger is already touching.
  static const int fast = 120;

  /// 200ms — the default for appearing and disappearing content.
  static const int base = 200;

  /// 300ms — full-screen transitions.
  static const int slow = 300;
}
