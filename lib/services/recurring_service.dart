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

    // Every transaction an earlier run already generated, keyed by the
    // subscription and the due moment it was generated for. The transaction
    // write and the cursor save below are two separate writes, so a kill
    // between them used to repeat the last transaction on the next launch;
    // consulting this set first makes the loop idempotent (L-4). Hand-entered
    // transactions carry no `subscriptionId` and are never matched.
    final generated = <String>{};
    for (final t in db.transactionsBox.values) {
      final sid = t.subscriptionId;
      if (sid != null) generated.add(_generatedKey(sid, t.date));
    }

    for (final sub in subs) {
      if (sub.isPaused) continue;
      try {
        final now = DateTime.now();
        bool changed = false;

        // The anchor day-of-month the cycle must always return to. Clamped
        // only when the target month is too short — a Jan-31 bill lands on
        // Feb 28 but is back on 31 in March, never stuck at 28.
        final anchorDay = anchorDayFor(sub.nextDueDate, sub.startDate);

        // A restored or hand-edited record can hold a next-due date earlier
        // than the subscription's start. Never generate charges for cycles
        // that predate the subscription itself.
        if (sub.nextDueDate.isBefore(sub.startDate)) continue;

        var cycles = 0;
        while (!sub.nextDueDate.isAfter(now) && cycles < _maxCatchUpCycles) {
          final key = _generatedKey(sub.id, sub.nextDueDate);
          if (!generated.contains(key)) {
            final txn = TransactionModel(
              title: sub.name,
              amount: sub.amount,
              date: sub.nextDueDate,
              // `!= 'income'` rather than `== 'expense'`, so an unrecognised
              // type books as an expense. The previous form defaulted the
              // unknown case to *income* while `balance_provider` defaulted
              // it to expense — the same record moved the two headline
              // numbers in opposite directions.
              isExpense: sub.type != 'income',
              subscriptionId: sub.id,
            )..isRecurring = true;
            await db.transactionsBox.add(txn);
            generated.add(key);
          }

          sub.nextDueDate = nextBillingDate(
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
        if (!sub.nextDueDate.isAfter(now)) {
          sub.nextDueDate = rollForward(
            sub.nextDueDate,
            sub.billingCycle,
            anchorDay,
            now,
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

  static String _generatedKey(String subscriptionId, DateTime due) =>
      '$subscriptionId|${due.millisecondsSinceEpoch}';

  /// The day-of-month a monthly-family cycle returns to.
  ///
  /// Taken from [nextDueDate], so a hand-edited next-due date sticks for
  /// every following cycle instead of snapping back to the start day after
  /// one cycle (L-2). The one exception is a next-due date that is the last
  /// day of a month shorter than the start day — that is a clamped Jan-31
  /// bill sitting on Feb 28, and it must return to the 31st.
  static int anchorDayFor(DateTime nextDueDate, DateTime startDate) {
    final lastDayOfMonth =
        DateTime(nextDueDate.year, nextDueDate.month + 1, 0).day;
    if (nextDueDate.day == lastDayOfMonth && startDate.day > nextDueDate.day) {
      return startDate.day;
    }
    return nextDueDate.day;
  }

  /// The first due date strictly after [now], stepping from [due] by [cycle]
  /// without generating anything. Used when a paused item is resumed (M-1)
  /// and when the catch-up cap is exceeded.
  static DateTime rollForward(
    DateTime due,
    String cycle,
    int anchorDay,
    DateTime now,
  ) {
    var next = due;
    while (!next.isAfter(now)) {
      next = nextBillingDate(next, cycle, anchorDay);
    }
    return next;
  }

  /// The next billing date for a cycle.
  ///
  /// Every cycle is built calendar-first. The weekly family used to add a
  /// `Duration` of whole days, which is an absolute span: across a
  /// daylight-saving change the result lands an hour off, and for a date
  /// stored at local midnight that hour is the previous calendar day (M-2).
  /// Monthly-family and yearly cycles are built around the [anchorDay] of
  /// month, so a month-end day returns to itself in a longer month instead of
  /// being carried forward clamped.
  static DateTime nextBillingDate(
    DateTime current,
    String cycle,
    int anchorDay,
  ) {
    switch (cycle) {
      case 'Weekly':
        return _addDays(current, 7);
      case 'Bi-Weekly':
        return _addDays(current, 14);
      case '3 Weeks':
        return _addDays(current, 21);
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

  /// Adds calendar days, keeping the wall-clock time. `DateTime` normalises
  /// an overflowing day into the following month, so this is DST-safe where
  /// `add(Duration(days: n))` is not.
  static DateTime _addDays(DateTime date, int days) => DateTime(
        date.year,
        date.month,
        date.day + days,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      );

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
