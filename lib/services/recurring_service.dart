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
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

class RecurringService {
  static const _lastProcessKey = 'recurring_last_process';

  /// Most transactions one item may generate in a single catch-up.
  ///
  /// Two years of monthly billing. Beyond this the due date is rolled forward
  /// without creating anything: a user who has genuinely been away that long
  /// wants a working app, not a ledger flooded with back-dated entries.
  static const _maxCatchUpCycles = 24;

  static Future<void> processDueItems() async {
    final db = DatabaseService();
    final subs = db.subscriptionsBox.values.toList();

    for (final sub in subs) {
      if (sub.isPaused) continue;
      try {
        final now = DateTime.now();
        bool changed = false;

        // The anchor day-of-month the cycle must always return to. Clamped
        // only when the target month is too short — a Jan-31 bill lands on
        // Feb 28 but is back on 31 in March, never stuck at 28.
        final anchorDay = sub.startDate.day;

        // A restored or hand-edited record can hold a next-due date earlier
        // than the subscription's start. Never generate charges for cycles
        // that predate the subscription itself.
        if (sub.nextDueDate.isBefore(sub.startDate)) continue;

        var cycles = 0;
        while (!sub.nextDueDate.isAfter(now) && cycles < _maxCatchUpCycles) {
          final txn = TransactionModel(
            title: sub.name,
            amount: sub.amount,
            date: sub.nextDueDate,
            // `!= 'income'` rather than `== 'expense'`, so an unrecognised type
            // books as an expense. The previous form defaulted the unknown case
            // to *income* while `balance_provider` defaulted it to expense —
            // the same record moved the two headline numbers in opposite
            // directions.
            isExpense: sub.type != 'income',
            subscriptionId: sub.id,
          )..isRecurring = true;
          await db.transactionsBox.add(txn);

          sub.nextDueDate = _nextBillingDate(
            sub.nextDueDate,
            sub.billingCycle,
            anchorDay,
          );
          cycles++;
          changed = true;

          // Persisted inside the loop, not once after it. Previously each
          // transaction was written immediately while the cursor was saved only
          // at the end, so any failure part-way through left N transactions on
          // disk with an unadvanced cursor — and the next launch silently wrote
          // all N again, with no way to detect or undo it.
          await sub.save();
        }

        // A date far in the past (the picker allows the year 2000, and an old
        // backup restores stale dates) would otherwise mean thousands of
        // awaited writes blocking the unlock screen. Past the cap the cursor is
        // rolled forward without creating anything.
        while (!sub.nextDueDate.isAfter(now)) {
          sub.nextDueDate = _nextBillingDate(
            sub.nextDueDate,
            sub.billingCycle,
            anchorDay,
          );
          changed = true;
        }
        if (changed) await sub.save();

        if (changed) {
          await NotificationService().scheduleNotification(sub);
        }
      } catch (e) {
        debugPrint('RecurringService: failed processing ${sub.name}: $e');
        continue;
      }
    }

    try {
      await db.settingsBox.put(_lastProcessKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('RecurringService: failed to persist last-process cursor: $e');
    }
  }

  /// The next billing date for a cycle.
  ///
  /// Daily/weekly-family cycles add a fixed [Duration] — those spans are short
  /// enough that DST shifts are immaterial. Monthly-family and yearly cycles
  /// are built calendar-first with `DateTime(year, month, day)` around the
  /// [anchorDay] of month, so a month-end day returns to itself in a longer
  /// month instead of being carried forward clamped.
  static DateTime _nextBillingDate(
    DateTime current,
    String cycle,
    int anchorDay,
  ) {
    switch (cycle) {
      case 'Weekly':
        return current.add(const Duration(days: 7));
      case 'Bi-Weekly':
        return current.add(const Duration(days: 14));
      case '3 Weeks':
        return current.add(const Duration(days: 21));
      case 'Monthly':
        return _addMonthsClamped(current, 1, anchorDay);
      case '3 Months':
        return _addMonthsClamped(current, 3, anchorDay);
      case '6 Months':
        return _addMonthsClamped(current, 6, anchorDay);
      case '9 Months':
        return _addMonthsClamped(current, 9, anchorDay);
      case 'Yearly':
        return _addMonthsClamped(current, 12, anchorDay);
      default:
        return _addMonthsClamped(current, 1, anchorDay);
    }
  }

  static DateTime _addMonthsClamped(
    DateTime date,
    int months,
    int anchorDay,
  ) {
    final targetYear = date.year + (date.month + months - 1) ~/ 12;
    final targetMonth = (date.month + months - 1) % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = anchorDay > lastDay ? lastDay : anchorDay;
    return DateTime(targetYear, targetMonth, day);
  }
}
