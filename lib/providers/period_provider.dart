// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The slice of time the Overview frames its activity with.
///
/// Deliberately **not persisted**. Every other user preference lives in the
/// settings box, but the period is a view state, not a preference: opening the
/// app three weeks later and landing on a stale month would misreport the
/// current month's activity to someone who has not touched the setting. It also
/// keeps this change free of any new storage key, which the rebuild rules
/// forbid while real testers hold live data.
@immutable
sealed class Period {
  const Period();

  /// Whether [date] falls inside this period.
  bool contains(DateTime date);
}

/// No filtering — every transaction ever recorded.
final class AllTime extends Period {
  const AllTime();

  @override
  bool contains(DateTime date) => true;

  @override
  bool operator ==(Object other) => other is AllTime;

  @override
  int get hashCode => 0;
}

/// One calendar month.
final class MonthOf extends Period {
  const MonthOf(this.year, this.month);

  factory MonthOf.containing(DateTime date) => MonthOf(date.year, date.month);

  final int year;

  /// 1–12.
  final int month;

  /// Midnight on the first day — what `DateFormat` needs to name the month.
  DateTime get firstDay => DateTime(year, month);

  MonthOf get previous =>
      month == 1 ? MonthOf(year - 1, 12) : MonthOf(year, month - 1);

  MonthOf get next =>
      month == 12 ? MonthOf(year + 1, 1) : MonthOf(year, month + 1);

  @override
  bool contains(DateTime date) => date.year == year && date.month == month;

  @override
  bool operator ==(Object other) =>
      other is MonthOf && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class PeriodNotifier extends Notifier<Period> {
  @override
  Period build() => MonthOf.containing(DateTime.now());

  void showPreviousMonth() {
    final current = state;
    if (current is MonthOf) state = current.previous;
  }

  void showNextMonth() {
    final current = state;
    if (current is MonthOf) state = current.next;
  }

  void showAllTime() => state = const AllTime();

  void showCurrentMonth() => state = MonthOf.containing(DateTime.now());
}

final periodProvider = NotifierProvider<PeriodNotifier, Period>(
  PeriodNotifier.new,
);
