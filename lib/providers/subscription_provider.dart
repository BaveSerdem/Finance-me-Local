import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

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
      return;
    }
    state = [...state, subscription];

    if (!isPaused && notifyDayBefore) {
      await NotificationService().scheduleNotification(subscription);
    }
  }

  Future<void> deleteSubscription(SubscriptionModel subscription) async {
    try {
      await subscription.delete();
    } catch (_) {
      return;
    }
    state = state.where((s) => s.id != subscription.id).toList();

    await NotificationService().cancelNotification(subscription.id);
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
    existing.name = name;
    existing.amount = amount;
    existing.type = type;
    existing.billingCycle = billingCycle;
    existing.startDate = startDate;
    existing.nextDueDate = nextDueDate;
    existing.isPaused = isPaused;
    existing.notifyDayBefore = notifyDayBefore;
    try {
      await existing.save();
    } catch (_) {
      return;
    }
    state = state.map((s) => s.id == existing.id ? existing : s).toList();

    await NotificationService().cancelNotification(existing.id);
    if (!isPaused && notifyDayBefore) {
      await NotificationService().scheduleNotification(existing);
    }
  }

  Future<void> togglePause(SubscriptionModel sub) async {
    sub.isPaused = !sub.isPaused;
    try {
      await sub.save();
    } catch (_) {
      return;
    }
    state = state.map((s) => s.id == sub.id ? sub : s).toList();

    if (sub.isPaused) {
      await NotificationService().cancelNotification(sub.id);
    } else if (sub.notifyDayBefore) {
      await NotificationService().scheduleNotification(sub);
    }
  }
}
