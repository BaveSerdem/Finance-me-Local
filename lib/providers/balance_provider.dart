import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
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

final balanceProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionProvider);
  final adjustment = ref.watch(adjustedBalanceProvider);

  double totalIncome = 0;
  double totalExpenses = 0;

  for (final t in transactions) {
    if (t.isExpense) {
      totalExpenses += t.amount;
    } else {
      totalIncome += t.amount;
    }
  }

  return {
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
    'balance': totalIncome - totalExpenses + adjustment,
  };
});

final miniDashboardProvider = Provider<Map<String, double>>((ref) {
  final subscriptions = ref.watch(subscriptionProvider);

  double monthlyIncome = 0;
  double monthlySubs = 0;

  for (final s in subscriptions) {
    if (s.isPaused) continue;
    final monthlyAmount = _toMonthlyAmount(s.amount, s.billingCycle);
    if (s.type == 'income') {
      monthlyIncome += monthlyAmount;
    } else {
      monthlySubs += monthlyAmount;
    }
  }

  return {'monthlyIncome': monthlyIncome, 'monthlySubs': monthlySubs};
});

double _toMonthlyAmount(double amount, String cycle) {
  switch (cycle) {
    case 'Weekly':
      return amount * 4.33;
    case 'Bi-Weekly':
      return amount * 2.17;
    case '3 Weeks':
      return amount * 1.44;
    case 'Monthly':
      return amount;
    case '3 Months':
      return amount / 3;
    case '6 Months':
      return amount / 6;
    case '9 Months':
      return amount / 9;
    case 'Yearly':
      return amount / 12;
    default:
      return amount;
  }
}
