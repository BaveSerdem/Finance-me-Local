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
import '../models/billing_cycle.dart';
import '../services/database_service.dart';
import 'period_provider.dart';
import 'transaction_provider.dart';
import 'subscription_provider.dart';

class AdjustedBalanceNotifier extends Notifier<double> {
  static const _key = 'adjusted_balance';

  @override
  double build() => _load();

  double _load() {
    final val = DatabaseService().settingsBox.get(_key);
    return double.tryParse(val ?? '') ?? 0;
  }

  Future<void> setBalance(double value) async {
    await DatabaseService().settingsBox.put(_key, value.toString());
    state = value;
  }

  void refresh() => state = _load();
}

final adjustedBalanceProvider =
    NotifierProvider<AdjustedBalanceNotifier, double>(
      AdjustedBalanceNotifier.new,
    );

/// What the balance header shows.
///
/// Replaces a `Map<String, double>` whose three magic keys were read back with
/// `!` at every call site — `balance['totalIncome']!`. A typo in one of those
/// strings produced a null-check crash at runtime with no analyzer warning, in
/// a widget that renders on first launch.
///
/// [balance] is deliberately **all-time**: it is the user's actual money, so
/// scoping it to a month would make an eleven-month-old account read as if it
/// held only December's net. The period frames *activity*, which is what
/// [income] and [expenses] report.
@immutable
class BalanceSummary {
  const BalanceSummary({
    required this.income,
    required this.expenses,
    required this.balance,
  });

  /// Income recorded inside the selected period.
  final double income;

  /// Expenses recorded inside the selected period.
  final double expenses;

  /// All-time income − expenses, plus the user's manual adjustment.
  final double balance;
}

final balanceProvider = Provider<BalanceSummary>((ref) {
  final transactions = ref.watch(transactionProvider);
  final adjustment = ref.watch(adjustedBalanceProvider);
  final period = ref.watch(periodProvider);

  double periodIncome = 0;
  double periodExpenses = 0;
  double lifetimeIncome = 0;
  double lifetimeExpenses = 0;

  for (final t in transactions) {
    if (t.isExpense) {
      lifetimeExpenses += t.amount;
      if (period.contains(t.date)) periodExpenses += t.amount;
    } else {
      lifetimeIncome += t.amount;
      if (period.contains(t.date)) periodIncome += t.amount;
    }
  }

  return BalanceSummary(
    income: periodIncome,
    expenses: periodExpenses,
    balance: lifetimeIncome - lifetimeExpenses + adjustment,
  );
});

/// The monthly run-rate of active recurring items.
///
/// Not scoped by the period: recurring items are forward-looking by nature, so
/// "what do I owe per month" does not change because the user paged back to
/// look at March.
@immutable
class RecurringSummary {
  const RecurringSummary({
    required this.monthlyIncome,
    required this.monthlyExpenses,
  });

  final double monthlyIncome;
  final double monthlyExpenses;
}

final recurringSummaryProvider = Provider<RecurringSummary>((ref) {
  final subscriptions = ref.watch(subscriptionProvider);

  double monthlyIncome = 0;
  double monthlyExpenses = 0;

  for (final s in subscriptions) {
    if (s.isPaused) continue;
    final monthlyAmount = BillingCycle.toMonthly(s.amount, s.billingCycle);
    if (s.type == 'income') {
      monthlyIncome += monthlyAmount;
    } else {
      monthlyExpenses += monthlyAmount;
    }
  }

  return RecurringSummary(
    monthlyIncome: monthlyIncome,
    monthlyExpenses: monthlyExpenses,
  );
});
