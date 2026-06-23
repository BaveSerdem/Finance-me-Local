import 'package:hive_ce/hive.dart';

/// Represents a single financial transaction (expense or income).
///
/// [isRecurring] marks an income entry for automatic monthly
/// re-injection at the start of each new calendar month.
@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  TransactionModel({
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
  });

  @HiveField(0)
  late String title;

  @HiveField(1)
  late double amount;

  @HiveField(2)
  late DateTime date;

  @HiveField(3)
  late bool isExpense;

  @HiveField(4)
  bool isRecurring = false;
}
