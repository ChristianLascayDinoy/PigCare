import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/services/notification_service.dart';
import 'package:uuid/uuid.dart';

part 'feeding_schedule_model.g.dart';

@HiveType(typeId: 3)
class FeedingSchedule {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String pigId;

  @HiveField(2)
  final String pigName;

  @HiveField(3)
  final String pigpenId;

  @HiveField(4)
  final String feedType;

  @HiveField(5)
  final double quantity;

  @HiveField(6)
  final String time;

  @HiveField(7)
  final DateTime date;

  @HiveField(8)
  final int notificationId;

  @HiveField(9)
  bool isFeedDeducted; // Track if feed has been deducted

  FeedingSchedule({
    String? id,
    required this.pigId,
    required this.pigName,
    required this.pigpenId,
    required this.feedType,
    required this.quantity,
    required this.time,
    required this.date,
    required this.notificationId,
    this.isFeedDeducted = false,
  }) : id = id ?? const Uuid().v4();

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
      await box.delete(id); // Delete using ID instead of index
    } catch (e) {
      throw Exception('Failed to delete schedule: ${e.toString()}');
    }
  }

  Future<void> executeFeeding() async {
    if (isFeedDeducted) return; // Skip if already deducted

    final feedBox = await Hive.openBox<Feed>('feedsBox');
    final feeds = feedBox.values.where((f) => f.name == feedType).toList();

    if (feeds.isEmpty) {
      throw Exception('Feed type $feedType not found');
    }

    final feed = feeds.first;
    if (feed.remainingQuantity < quantity) {
      throw Exception('Not enough $feedType available');
    }

    feed.deductFeed(quantity);
    await feedBox.put(feed.id, feed);

    // Mark as deducted
    isFeedDeducted = true;
    final scheduleBox = await Hive.openBox<FeedingSchedule>('feedingSchedules');
    await scheduleBox.put(id, this);
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
      payload: id, // Pass schedule ID to handle when notification is received
    );
  }

  factory FeedingSchedule.create({
    String? id,
    required String pigId,
    required String pigName,
    required String pigpenId,
    required String feedType,
    required double quantity,
    required String time,
    required DateTime date,
  }) {
    return FeedingSchedule(
      id: id,
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
