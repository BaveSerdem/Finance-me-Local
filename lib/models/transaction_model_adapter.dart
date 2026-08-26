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
import 'transaction_model.dart';

/// Manually written TypeAdapter for [TransactionModel].
/// Avoids the need for code generation and its dependency conflicts.
///
/// Field 4 ([isRecurring]) is wrapped in a try-catch so that existing
/// Hive boxes created before this field existed continue to load
/// without errors.
class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final title = reader.readString();
    final amount = reader.readDouble();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final isExpense = reader.readBool();

    bool isRecurring = false;
    try {
      isRecurring = reader.readBool();
    } catch (_) {
      isRecurring = false;
    }

    String? subscriptionId;
    try {
      subscriptionId = reader.readString();
    } catch (_) {
      subscriptionId = null;
    }
    if (subscriptionId != null && subscriptionId.isEmpty) subscriptionId = null;

    final t = TransactionModel(
      title: title,
      amount: amount,
      date: date,
      isExpense: isExpense,
      subscriptionId: subscriptionId,
    );
    t.isRecurring = isRecurring;
    return t;
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer.writeString(obj.title);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeBool(obj.isExpense);
    writer.writeBool(obj.isRecurring);
    writer.writeString(obj.subscriptionId ?? '');
  }
}
