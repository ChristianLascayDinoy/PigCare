import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:pigcare/core/models/feeding_schedule_model.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handleNotificationResponse(response.payload); // Handle notification tap
      },
    );
  }

  Future<void> scheduleFeedingNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required DateTime date,
    String? payload, // Add this parameter
  }) async {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final notificationDate = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'feeding_channel',
      'Feeding Reminders',
      channelDescription: 'Notifications for scheduled pig feedings',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationDate, tz.local),
      const NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload, // Pass the payload here
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

// In NotificationService.dart
  Future<void> handleNotificationResponse(String? payload) async {
    if (payload == null) return;

    try {
      final box = await Hive.openBox<FeedingSchedule>('feedingSchedules');
      final schedule = box.get(payload);

      if (schedule != null && !schedule.isFeedDeducted) {
        await schedule.executeFeeding();

        // Update the schedule in Hive
        schedule.isFeedDeducted = true;
        await box.put(schedule.id, schedule);
      }
    } catch (e) {
      debugPrint('Error handling feeding notification: $e');
      // You might want to show a notification that the feeding failed
    }
  }

  // In NotificationService.dart
  Future<void> checkMissedSchedules() async {
    final now = DateTime.now();
    final box = await Hive.openBox<FeedingSchedule>('feedingSchedules');

    for (final schedule in box.values) {
      final scheduleTime = schedule.timeOfDay;
      final scheduleDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        scheduleTime.hour,
        scheduleTime.minute,
      );

      // If the schedule time has passed today and feed wasn't deducted
      if (scheduleDateTime.isBefore(now) && !schedule.isFeedDeducted) {
        try {
          await schedule.executeFeeding();
        } catch (e) {
          debugPrint('Failed to execute missed schedule: $e');
        }
      }
    }
  }
}
