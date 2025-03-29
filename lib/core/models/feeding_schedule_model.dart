import 'package:hive/hive.dart';

part 'feeding_schedule_model.g.dart';

@HiveType(typeId: 3)
class FeedingSchedule extends HiveObject {
  @HiveField(0)
  String pigId;

  @HiveField(1)
  String pigpenId;

  @HiveField(2)
  String feedType;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  String time;

  FeedingSchedule({
    required this.pigId,
    required this.pigpenId,
    required this.feedType,
    required this.quantity,
    required this.time,
    String? pigName,
    required DateTime date,
  });
}
