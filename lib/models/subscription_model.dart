import 'package:hive_ce/hive.dart';

@HiveType(typeId: 1)
class SubscriptionModel extends HiveObject {
  SubscriptionModel({
    required this.name,
    required this.amount,
    required this.type,
    required this.billingCycle,
    required this.startDate,
    required this.nextDueDate,
    this.isPaused = false,
    this.notifyDayBefore = true,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt = createdAt ?? DateTime.now();

  @HiveField(0)
  late String name;

  @HiveField(1)
  late double amount;

  @HiveField(2)
  late DateTime nextDueDate;

  @HiveField(3)
  late String billingCycle;

  @HiveField(4)
  bool notifyDayBefore = true;

  @HiveField(5)
  late String id;

  @HiveField(6)
  late String type;

  @HiveField(7)
  late DateTime startDate;

  @HiveField(8)
  bool isPaused = false;

  @HiveField(9)
  late DateTime createdAt;

  String get title => name;
  set title(String v) => name = v;

  DateTime get nextBillingDate => nextDueDate;
  set nextBillingDate(DateTime v) => nextDueDate = v;

  bool get enableNotification => notifyDayBefore;
  set enableNotification(bool v) => notifyDayBefore = v;
}
