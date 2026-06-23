import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

class RecurringService {
  static const _lastProcessKey = 'recurring_last_process';

  static Future<void> processDueItems() async {
    final db = DatabaseService();
    final subs = db.subscriptionsBox.values.toList();

    for (final sub in subs) {
      if (sub.isPaused) continue;
      try {
        final now = DateTime.now();
        bool changed = false;

        while (!sub.nextDueDate.isAfter(now)) {
          final txn = TransactionModel(
            title: sub.name,
            amount: sub.amount,
            date: sub.nextDueDate,
            isExpense: sub.type == 'expense',
          );
          await db.transactionsBox.add(txn);

          sub.nextDueDate = _nextBillingDate(sub.nextDueDate, sub.billingCycle);
          changed = true;
        }

        if (changed) {
          await sub.save();
          await NotificationService().scheduleNotification(sub);
        }
      } catch (_) {
        continue;
      }
    }

    await db.settingsBox.put(_lastProcessKey, DateTime.now().toIso8601String());
  }

  static DateTime _nextBillingDate(DateTime current, String cycle) {
    switch (cycle) {
      case 'Weekly':
        return current.add(const Duration(days: 7));
      case 'Bi-Weekly':
        return current.add(const Duration(days: 14));
      case '3 Weeks':
        return current.add(const Duration(days: 21));
      case 'Monthly':
        return _addMonthsClamped(current, 1);
      case '3 Months':
        return _addMonthsClamped(current, 3);
      case '6 Months':
        return _addMonthsClamped(current, 6);
      case '9 Months':
        return _addMonthsClamped(current, 9);
      case 'Yearly':
        return _addMonthsClamped(current, 12);
      default:
        return _addMonthsClamped(current, 1);
    }
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
    final targetYear = date.year + (date.month + months - 1) ~/ 12;
    final targetMonth = (date.month + months - 1) % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetYear, targetMonth, clampedDay);
  }
}
