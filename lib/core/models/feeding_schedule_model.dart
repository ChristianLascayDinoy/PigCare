import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pigcare/core/services/notification_service.dart';

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

  @HiveField(7)
  final int notificationId;

  FeedingSchedule({
    required this.pigId,
    required this.pigName,
    required this.pigpenId,
    required this.feedType,
    required this.quantity,
    required this.time,
    required this.date,
    required this.notificationId,
  });

  TimeOfDay get timeOfDay {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1].split(' ')[0]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0); // Default fallback
    }
  }

  Future<void> delete() async {
    final box = Hive.box<FeedingSchedule>('feedingSchedules');
    final notificationService = NotificationService();

    try {
      await notificationService.cancelNotification(notificationId);
      final key = box.keyAt(box.values.toList().indexOf(this));
      await box.delete(key);
    } catch (e) {
      throw Exception('Failed to delete schedule: ${e.toString()}');
    }
  }

  Future<void> scheduleNotification() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    await notificationService.scheduleFeedingNotification(
      id: notificationId,
      title: 'Feeding Time for $pigName',
      body: 'Feed $quantity kg of $feedType in $pigpenId',
      time: timeOfDay,
      date: date,
    );
  }

  factory FeedingSchedule.create({
    required String pigId,
    required String pigName,
    required String pigpenId,
    required String feedType,
    required double quantity,
    required String time,
    required DateTime date,
  }) {
    return FeedingSchedule(
      pigId: pigId,
      pigName: pigName,
      pigpenId: pigpenId,
      feedType: feedType,
      quantity: quantity,
      time: time,
      date: date,
      notificationId: pigId.hashCode ^
          feedType.hashCode ^
          (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
  }
}
