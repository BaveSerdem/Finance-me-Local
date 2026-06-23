import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/subscription_model.dart';
import '../providers/currency_provider.dart';
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

    final symbol = currencySymbols[
      DatabaseService().settingsBox.get('currency_code')
    ] ?? '\$';

    final id = _idFromString(sub.id);
    await cancelNotification(sub.id);

    final reminderDate = sub.nextDueDate.subtract(const Duration(days: 1));
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);

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
      'Upcoming Payment',
      '${sub.name} — $symbol${sub.amount.toStringAsFixed(2)} is due tomorrow',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(String subId) async {
    await _plugin.cancel(_idFromString(subId));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
