import 'package:hive/hive.dart';

part 'feeding_schedule_model.g.dart';

@HiveType(typeId: 3)
class FeedingSchedule {
  @HiveField(0)
  final String pigId;

  @HiveField(1)
  final String pigName;

  @HiveField(2)
  final String pigpenId;

  @HiveField(3)
  final String feedType;

  @HiveField(4)
  final double quantity;

  @HiveField(5)
  final String time;

  @HiveField(6)
  final DateTime date;

  FeedingSchedule({
    required this.pigId,
    required this.pigName,
    required this.pigpenId,
    required this.feedType,
    required this.quantity,
    required this.time,
    required this.date,
  });

  // Add this method for deletion
  Future<void> delete() async {
    final box = Hive.box<FeedingSchedule>('feedingSchedules');
    final key = box.keyAt(box.values.toList().indexOf(this));
    await box.delete(key);
  }
}
