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
import '../models/subscription_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/recurring_service.dart';

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, List<SubscriptionModel>>(
      SubscriptionNotifier.new,
    );

class SubscriptionNotifier extends Notifier<List<SubscriptionModel>> {
  @override
  List<SubscriptionModel> build() {
    return _box.values.toList();
  }

  Box<SubscriptionModel> get _box => DatabaseService().subscriptionsBox;

  Future<void> addSubscription({
    required String name,
    required double amount,
    required String type,
    required String billingCycle,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool isPaused = false,
    bool notifyDayBefore = true,
  }) async {
    final subscription = SubscriptionModel(
      name: name,
      amount: amount,
      type: type,
      billingCycle: billingCycle,
      startDate: startDate,
      nextDueDate: nextDueDate,
      isPaused: isPaused,
      notifyDayBefore: notifyDayBefore,
    );
    try {
      await _box.add(subscription);
    } catch (_) {
      rethrow;
    }
    state = [...state, subscription];

    if (!isPaused && notifyDayBefore) {
      try {
        await NotificationService().scheduleNotification(subscription);
      } catch (_) {}
    }
  }

  Future<void> deleteSubscription(SubscriptionModel subscription) async {
    try {
      await subscription.delete();
    } catch (_) {
      rethrow;
    }
    state = state.where((s) => s.id != subscription.id).toList();

    try {
      await NotificationService().cancelNotification(subscription.id);
    } catch (_) {}
  }

  Future<void> updateSubscription({
    required SubscriptionModel existing,
    required String name,
    required double amount,
    required String type,
    required String billingCycle,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool isPaused = false,
    bool notifyDayBefore = true,
  }) async {
    // Resumed through the form without touching the due date: same rule as
    // [togglePause]. A due date the user deliberately changed is respected.
    final resumedWithSameDueDate = existing.isPaused &&
        !isPaused &&
        existing.nextDueDate == nextDueDate;
    existing.name = name;
    existing.amount = amount;
    existing.type = type;
    existing.billingCycle = billingCycle;
    existing.startDate = startDate;
    existing.nextDueDate = nextDueDate;
    existing.isPaused = isPaused;
    existing.notifyDayBefore = notifyDayBefore;
    if (resumedWithSameDueDate) _skipCyclesMissedWhilePaused(existing);
    try {
      await existing.save();
    } catch (_) {
      rethrow;
    }
    state = state.map((s) => s.id == existing.id ? existing : s).toList();

    try {
      await NotificationService().cancelNotification(existing.id);
    } catch (_) {}
    if (!isPaused && notifyDayBefore) {
      try {
        await NotificationService().scheduleNotification(existing);
      } catch (_) {}
    }
  }

  Future<void> togglePause(SubscriptionModel sub) async {
    sub.isPaused = !sub.isPaused;
    if (!sub.isPaused) _skipCyclesMissedWhilePaused(sub);
    try {
      await sub.save();
    } catch (_) {
      rethrow;
    }
    state = state.map((s) => s.id == sub.id ? sub : s).toList();

    try {
      if (sub.isPaused) {
        await NotificationService().cancelNotification(sub.id);
      } else if (sub.notifyDayBefore) {
        await NotificationService().scheduleNotification(sub);
      }
    } catch (_) {}
  }

  /// A paused item keeps the due date it had when it was paused. Resuming it
  /// unchanged would hand that stale date to the catch-up loop, which would
  /// then book one transaction for every cycle that elapsed while paused —
  /// charges that never happened (M-1). Roll the cursor to the first due date
  /// after now instead, creating nothing.
  void _skipCyclesMissedWhilePaused(SubscriptionModel sub) {
    final now = DateTime.now();
    if (sub.nextDueDate.isAfter(now)) return;
    sub.nextDueDate = RecurringService.rollForward(
      sub.nextDueDate,
      sub.billingCycle,
      RecurringService.anchorDayFor(sub.nextDueDate, sub.startDate),
      now,
    );
  }
}
