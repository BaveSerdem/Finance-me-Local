// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../formatting/money_format.dart';
import '../localization/app_strings.dart';
import '../models/subscription_model.dart';
import '../services/database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) {},
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'subscription_reminders',
            'Subscription Reminders',
            description: 'Reminders for upcoming subscription payments',
            importance: Importance.defaultImportance,
          ),
        );
  }

  int _idFromString(String id) {
    return id.hashCode & 0x7FFFFFFF;
  }

  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return (await android.requestNotificationsPermission()) ?? false;
    }
    return false;
  }

  Future<void> scheduleNotification(SubscriptionModel sub) async {
    if (sub.isPaused || !sub.notifyDayBefore) return;

    // Built straight from the settings box: this service has no `WidgetRef`
    // and no `BuildContext`, which is why `MoneyFormat` is a value class rather
    // than a provider. It also means notifications finally respect the user's
    // custom symbol and left/right position, which the old inline lookup here
    // ignored entirely.
    final settings = DatabaseService().settingsBox;
    final money = MoneyFormat.fromSettings(settings);

    // Same source as the UI. Read straight from the settings box rather than
    // through `localeProvider`, for the same reason `MoneyFormat` is a value
    // class here: this service runs with no `WidgetRef` and no `BuildContext`.
    //
    // Reminders already queued with the OS keep the language they were
    // scheduled in — re-scheduling the whole box on every language change is
    // background work traded for a cosmetic gain, so it is deliberately not
    // done. A reminder is rewritten in the new language the next time its
    // subscription is saved.
    final lang = settings.get('app_language') ?? 'en';

    final id = _idFromString(sub.id);
    await cancelNotification(sub.id);

    final now = DateTime.now();
    // Only a due date that has genuinely passed is skipped. A subscription due
    // today or tomorrow must still be reminded: its reminder moment (due − 1
    // day) has already gone by in that case, and clamping it forward instead of
    // dropping it is what keeps the "remind 1 day before" promise.
    if (sub.nextDueDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return;
    }

    final reminderDate = sub.nextDueDate.subtract(const Duration(days: 1));
    // `zonedSchedule` requires a strictly future moment, so a same-day or
    // already-elapsed reminder is pushed a few seconds out rather than
    // scheduled in the past.
    final scheduledMoment = reminderDate.isAfter(now)
        ? reminderDate
        : now.add(const Duration(seconds: 5));

    final scheduledDate = tz.TZDateTime.from(scheduledMoment, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'subscription_reminders',
      'Subscription Reminders',
      channelDescription: 'Reminders for upcoming subscription payments',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      AppStrings.get('notif_payment_title', lang),
      AppStrings.format('notif_payment_body', lang, {
        'name': sub.name,
        'amount': money.amount(sub.amount),
      }),
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(String subId) async {
    await _plugin.cancel(_idFromString(subId));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
