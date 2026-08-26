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

import '../models/transaction_model.dart';
import 'format_provider.dart';
import 'period_provider.dart';
import 'transaction_provider.dart';

/// One bar on the activity chart.
@immutable
class ActivityBucket {
  const ActivityBucket({
    required this.label,
    required this.income,
    required this.expenses,
  });

  /// Already localised — a day number, or a short month name.
  final String label;
  final double income;
  final double expenses;
}

/// Everything the Analytics screen draws, computed over **one** range.
///
/// This is the fix the whole screen existed to need: the bar chart used to
/// plot the last seven days while the totals beneath it summed the entire
/// history. Two unlabelled figures answered two different questions on one
/// screen, and nothing on it said so. Both now come from the same
/// [periodProvider] value, so the chart and the totals always describe the
/// same span.
@immutable
class AnalyticsData {
  const AnalyticsData({
    required this.buckets,
    required this.totalIncome,
    required this.totalExpenses,
    required this.incomeCount,
    required this.expenseCount,
  });

  final List<ActivityBucket> buckets;
  final double totalIncome;
  final double totalExpenses;
  final int incomeCount;
  final int expenseCount;

  bool get isEmpty => incomeCount + expenseCount == 0;

  double get net => totalIncome - totalExpenses;

  /// The tallest single bar, used to scale the axis.
  double get peak => buckets.fold<double>(
        0,
        (max, b) => [max, b.income, b.expenses].reduce((a, c) => a > c ? a : c),
      );
}

final analyticsProvider = Provider<AnalyticsData>((ref) {
  final transactions = ref.watch(transactionProvider);
  final period = ref.watch(periodProvider);
  final dates = ref.watch(dateFormatProvider);

  final visible =
      transactions.where((t) => period.contains(t.date)).toList(growable: false);

  double totalIncome = 0;
  double totalExpenses = 0;
  int incomeCount = 0;
  int expenseCount = 0;
  for (final t in visible) {
    if (t.isExpense) {
      totalExpenses += t.amount;
      expenseCount++;
    } else {
      totalIncome += t.amount;
      incomeCount++;
    }
  }

  final buckets = switch (period) {
    MonthOf() => _bucketByWeekOfMonth(visible, period),
    AllTime() => _bucketByMonth(visible, dates.monthShort),
  };

  return AnalyticsData(
    buckets: buckets,
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    incomeCount: incomeCount,
    expenseCount: expenseCount,
  );
});

/// Five fixed blocks: days 1–7, 8–14, 15–21, 22–28, 29+.
///
/// Blocks rather than days because a month is 28–31 bars, which at any readable
/// bar width will not fit a phone. Fixed boundaries rather than ISO weeks so
/// the labels are plain day numbers and need no translation.
List<ActivityBucket> _bucketByWeekOfMonth(
  List<TransactionModel> transactions,
  MonthOf month,
) {
  const starts = [1, 8, 15, 22, 29];
  final income = List<double>.filled(starts.length, 0);
  final expenses = List<double>.filled(starts.length, 0);

  for (final t in transactions) {
    final index = ((t.date.day - 1) ~/ 7).clamp(0, starts.length - 1);
    if (t.isExpense) {
      expenses[index] += t.amount;
    } else {
      income[index] += t.amount;
    }
  }

  // A 28-day February has no 29+ block, so it is dropped rather than drawn as
  // a permanently empty bar.
  final lastDay = DateTime(month.year, month.month + 1, 0).day;

  return [
    for (var i = 0; i < starts.length; i++)
      if (starts[i] <= lastDay)
        ActivityBucket(
          label: '${starts[i]}',
          income: income[i],
          expenses: expenses[i],
        ),
  ];
}

/// The last twelve months that carry data, oldest first.
List<ActivityBucket> _bucketByMonth(
  List<TransactionModel> transactions,
  String Function(DateTime) labelOf,
) {
  if (transactions.isEmpty) return const [];

  final income = <DateTime, double>{};
  final expenses = <DateTime, double>{};

  for (final t in transactions) {
    final key = DateTime(t.date.year, t.date.month);
    if (t.isExpense) {
      expenses[key] = (expenses[key] ?? 0) + t.amount;
    } else {
      income[key] = (income[key] ?? 0) + t.amount;
    }
  }

  final months = {...income.keys, ...expenses.keys}.toList()..sort();
  final recent = months.length > 12
      ? months.sublist(months.length - 12)
      : months;

  return [
    for (final month in recent)
      ActivityBucket(
        label: labelOf(month),
        income: income[month] ?? 0,
        expenses: expenses[month] ?? 0,
      ),
  ];
}

/// Rounds [peak] up to the next 1, 2 or 5 × 10ⁿ so the axis lands on round
/// numbers.
///
/// The chart used `maxY * 1.2`, which produced ticks like `$16 / $33 / $49 /
/// $66` — four numbers no reader can compare at a glance. Snapping the top to
/// a clean step makes every gridline a clean fraction of it.
double niceAxisMax(double peak) {
  if (peak <= 0) return 100;

  var magnitude = 1.0;
  while (peak / magnitude >= 10) {
    magnitude *= 10;
  }
  while (peak / magnitude < 1) {
    magnitude /= 10;
  }

  final normalised = peak / magnitude;
  final step = switch (normalised) {
    <= 1 => 1.0,
    <= 2 => 2.0,
    <= 4 => 4.0,
    <= 5 => 5.0,
    _ => 10.0,
  };
  return step * magnitude;
}
