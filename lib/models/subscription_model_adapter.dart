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
import 'subscription_model.dart';

class SubscriptionModelAdapter extends TypeAdapter<SubscriptionModel> {
  @override
  final int typeId = 1;

  @override
  SubscriptionModel read(BinaryReader reader) {
    String title = '';
    double amount = 0.0;
    DateTime nextBillingDate = DateTime.now();
    String billingCycle = 'Monthly';
    bool enableNotification = true;
    String id = '';
    String type = 'expense';
    DateTime startDate = DateTime.now();
    bool isPaused = false;
    DateTime createdAt = DateTime.now();

    title = reader.readString();
    amount = reader.readDouble();
    nextBillingDate = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    billingCycle = reader.readString();
    enableNotification = reader.readBool();

    try {
      if (reader.availableBytes > 0) id = reader.readString();
      if (reader.availableBytes > 0) type = reader.readString();
      if (reader.availableBytes > 0) startDate = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
      if (reader.availableBytes > 0) isPaused = reader.readBool();
      if (reader.availableBytes > 0) createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    } catch (_) {
      // Ignore partial/legacy trailing fields; defaults above apply.
    }

    final model = SubscriptionModel(
      name: title,
      amount: amount,
      type: type,
      billingCycle: billingCycle,
      startDate: startDate,
      nextDueDate: nextBillingDate,
      isPaused: isPaused,
      notifyDayBefore: enableNotification,
      id: id,
      createdAt: createdAt,
    );
    if (model.id.isEmpty) {
      model.id = DateTime.now().microsecondsSinceEpoch.toString();
      model.idWasRegenerated = true;
    }
    return model;
  }

  @override
  void write(BinaryWriter writer, SubscriptionModel obj) {
    writer.writeString(obj.title);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.nextBillingDate.millisecondsSinceEpoch);
    writer.writeString(obj.billingCycle);
    writer.writeBool(obj.enableNotification);
    writer.writeString(obj.id);
    writer.writeString(obj.type);
    writer.writeInt(obj.startDate.millisecondsSinceEpoch);
    writer.writeBool(obj.isPaused);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
