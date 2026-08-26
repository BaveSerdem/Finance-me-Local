// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

/// The eight billing cycles a recurring item can use.
///
/// Before this existed the same eight English strings were written out **four**
/// separate times:
///
/// * `home_screen.dart` — the subscription form's dropdown
/// * `recurring_items_screen.dart` — the recurring form's dropdown, byte-identical
/// * `recurring_items_screen.dart` — a second map turning them into l10n keys
/// * `balance_provider.dart` — `_toMonthlyAmount`, a switch converting them to
///   a monthly figure
///
/// The last one is why this matters beyond tidiness. Editing any one list
/// without the others would leave the mini dashboard computing the wrong
/// monthly total **silently** — no crash, no warning, just a wrong number in a
/// finance app.
///
/// [storageValue] is the exact string already written into Hive. It must never
/// change: existing records hold these values.
enum BillingCycle {
  weekly('Weekly', 'weekly', 4.33),
  biWeekly('Bi-Weekly', 'bi_weekly', 2.17),
  threeWeeks('3 Weeks', 'every_3_weeks', 1.44),
  monthly('Monthly', 'monthly', 1),
  threeMonths('3 Months', 'every_3_months', 1 / 3),
  sixMonths('6 Months', 'every_6_months', 1 / 6),
  nineMonths('9 Months', 'every_9_months', 1 / 9),
  yearly('Yearly', 'yearly', 1 / 12);

  const BillingCycle(this.storageValue, this.l10nKey, this.monthlyFactor);

  /// The value persisted in Hive. Immutable — existing records depend on it.
  final String storageValue;

  /// Key into `AppStrings` for the translated label.
  final String l10nKey;

  /// Multiplier converting one charge into its monthly equivalent.
  final double monthlyFactor;

  /// Resolves a stored string, falling back to [monthly] for anything
  /// unrecognised — the same behaviour the old `switch` default had.
  static BillingCycle fromStorage(String? value) {
    for (final cycle in values) {
      if (cycle.storageValue == value) return cycle;
    }
    return monthly;
  }

  /// Converts a single charge of [amount] into its monthly equivalent.
  static double toMonthly(double amount, String? storedCycle) =>
      amount * fromStorage(storedCycle).monthlyFactor;

  /// Stored values in display order, for dropdowns.
  static List<String> get storageValues =>
      values.map((c) => c.storageValue).toList();
}
