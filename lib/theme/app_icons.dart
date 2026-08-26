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

/// The app's semantic glyphs.
///
/// Exists for the same reason `BillingCycle` exists: the same concept was being
/// spelled out separately at each call site, and the copies drifted. The
/// balance header used `Icons.call_received` for income and `Icons.call_made`
/// for expense — telephony glyphs, pointing **down-left** and **up-right** —
/// while the recurring strip sixteen pixels below it used `arrow_upward` and
/// `arrow_downward`. Two adjacent rows showed the same two concepts with
/// opposite arrow directions, and nothing in the type system objected.
///
/// The direction is settled by a channel the app already commits to:
/// `MoneyFormat.signed` emits `+` for income and `−` for expense, and
/// `MoneyText` prints those signs explicitly in colourblind mode. An arrow
/// pointing up is the only one that agrees with a leading `+`.
abstract final class AppIcons {
  /// Money in. Pairs with `+` and [AppPalette.income].
  static const IconData income = Icons.arrow_upward;

  /// Money out. Pairs with `−` and [AppPalette.expense].
  static const IconData expense = Icons.arrow_downward;

  /// A recurring item, anywhere it needs a glyph.
  static const IconData recurring = Icons.repeat;

  /// A recurring item the user has suspended.
  static const IconData paused = Icons.pause;

  /// Resume a suspended item.
  static const IconData resume = Icons.play_arrow;

  /// Leads to another screen or destination.
  static const IconData forward = Icons.chevron_right;

  /// The direction for [income] or [expense], chosen by the same flag every
  /// amount in the app is stored with.
  static IconData amount({required bool isExpense}) =>
      isExpense ? expense : income;
}
