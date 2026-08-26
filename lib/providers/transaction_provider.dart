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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

final transactionProvider =
    NotifierProvider<TransactionNotifier, List<TransactionModel>>(
      TransactionNotifier.new,
    );

class TransactionNotifier extends Notifier<List<TransactionModel>> {
  @override
  List<TransactionModel> build() {
    return _box.values.toList();
  }

  Box<TransactionModel> get _box => DatabaseService().transactionsBox;

  Future<void> addTransaction({
    required String title,
    required double amount,
    required DateTime date,
    required bool isExpense,
  }) async {
    final transaction = TransactionModel(
      title: title,
      amount: amount,
      date: date,
      isExpense: isExpense,
    );
    try {
      await _box.add(transaction);
    } catch (_) {
      return;
    }
    state = [...state, transaction];
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    try {
      await transaction.delete();
    } catch (_) {
      return;
    }
    state = state.where((t) => t.key != transaction.key).toList();
  }

  Future<void> updateTransaction({
    required TransactionModel existing,
    required String title,
    required double amount,
    required DateTime date,
    required bool isExpense,
  }) async {
    existing.title = title;
    existing.amount = amount;
    existing.date = date;
    existing.isExpense = isExpense;
    try {
      await existing.save();
    } catch (_) {
      return;
    }
    state = state.map((t) => t.key == existing.key ? existing : t).toList();
  }
}
