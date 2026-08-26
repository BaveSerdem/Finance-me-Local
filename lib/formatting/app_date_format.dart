// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:intl/intl.dart';

import 'intl_locale.dart';

/// Formats every date the app displays.
///
/// Previously each call site built its own bare `DateFormat.yMMMd()` with no
/// locale, so `intl` silently fell back to `en_US` for all six languages — an
/// Arabic user read `الرصيد الإجمالي` above a transaction dated `JAN 15` at
/// `3:04 PM`, and a German user got `Jan 15, 2026` instead of `15.01.2026`.
///
/// Requires `initializeDateFormatting()` to have run in `main`.
class AppDateFormat {
  AppDateFormat(String languageCode) : _tag = intlTagFor(languageCode);

  final String _tag;

  /// Group heading above a day's transactions.
  ///
  /// Note there is no `.toUpperCase()` here, unlike the code this replaces.
  /// Dart's `toUpperCase` is not locale-aware — it turns Turkish `i` into `I`
  /// rather than `İ` — and uppercased month abbreviations look wrong in Arabic
  /// and Russian regardless. Emphasis belongs to weight and letter-spacing.
  String dayHeader(DateTime date) => DateFormat.MMMd(_tag).format(date);

  /// Time of day, in the locale's own convention.
  String time(DateTime date) => DateFormat.jm(_tag).format(date);

  /// A full date: `Jan 15, 2026`, `15.01.2026`, `١٥‏/٠١‏/٢٠٢٦`.
  String mediumDate(DateTime date) => DateFormat.yMMMd(_tag).format(date);

  /// Short weekday for chart axes, replacing the hardcoded English
  /// `['Mon' … 'Sun']` array the analytics screen used to carry.
  String weekdayShort(DateTime date) => DateFormat.E(_tag).format(date);

  /// Month and year, for the period navigator: `August 2026`, `أغسطس ٢٠٢٦`.
  String monthYear(DateTime date) => DateFormat.yMMMM(_tag).format(date);

  /// Abbreviated month, for chart axes: `Aug`, `أغس`.
  String monthShort(DateTime date) => DateFormat.MMM(_tag).format(date);
}
