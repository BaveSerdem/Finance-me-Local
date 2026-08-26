// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

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
    this.subscriptionId,
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

  /// The subscription that generated this transaction, when it came from
  /// [RecurringService]. Null for hand-entered transactions.
  @HiveField(5)
  String? subscriptionId;
}
