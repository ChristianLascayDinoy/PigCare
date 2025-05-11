import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/task_model.dart';
import 'package:pigcare/core/models/expense_model.dart';
import 'package:pigcare/core/models/sale_model.dart';
import 'package:pigcare/core/services/notification_service.dart';
import 'package:pigcare/core/views/intro/loading_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pigcare/core/models/feeding_schedule_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/views/dashboard/dashboard_screen.dart';
import 'package:pigcare/core/views/intro/intro_screen.dart';
import 'package:pigcare/core/providers/feed_expense_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show loading screen immediately
  runApp(
    const MaterialApp(
      home: LoadingScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );

  try {
    await _initializeHive();
    await _initializeAppData();
    await Hive.openBox('settings');

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
    await _rescheduleAllNotifications();
    await _checkPendingFeedings();
    await notificationService.checkMissedSchedules();

    // Now run the actual app with the provider
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FeedExpenseProvider()),
          // Add other providers here if needed
        ],
        child: const PigCareApp(),
      ),
    );
  } catch (e) {
    runApp(_ErrorApp(error: e));
  }
}

class _ErrorApp extends StatelessWidget {
  final dynamic error;

  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.green[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  'Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Failed to initialize app: ${error.toString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  onPressed: () => main(),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Initialization Functions
Future<void> _initializeHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(PigpenAdapter());
  Hive.registerAdapter(PigAdapter());
  Hive.registerAdapter(FeedAdapter());
  Hive.registerAdapter(FeedingScheduleAdapter());
  Hive.registerAdapter(PigTaskAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(SaleAdapter());

  await Future.wait([
    _openBox<Pigpen>('pigpens'),
    _openBox<Pig>('pigs'),
    _openBox<Feed>('feedsBox'),
    _openBox<FeedingSchedule>('feedingSchedules'),
    _openBox<PigTask>('pig_tasks'),
    _openBox<Expense>('expenses'),
    _openBox<Sale>('sales'),
  ]);
}

Future<void> _openBox<T>(String boxName) async {
  try {
    await Hive.openBox<T>(boxName);
  } catch (e) {
    debugPrint('Error opening box $boxName: ${e.toString()}');
    await Hive.deleteBoxFromDisk(boxName);
    await Hive.openBox<T>(boxName);
  }
}

Future<void> _initializeAppData() async {
  await _initializeUnassignedPigpen();
  await _performDataMigrations();
}

Future<void> _initializeUnassignedPigpen() async {
  final pigpenBox = Hive.box<Pigpen>('pigpens');
  final hasUnassigned = pigpenBox.values.any((p) => p.name == "Unassigned");

  if (!hasUnassigned) {
    final unassigned = Pigpen(
      name: "Unassigned",
      description: "Pigs not assigned to any specific pigpen",
    );
    await pigpenBox.add(unassigned);
  }
}

Future<void> _performDataMigrations() async {
  final prefs = await SharedPreferences.getInstance();
  final hasMigrated = prefs.getBool('hasMigratedPigpenRefs') ?? false;

  if (!hasMigrated) {
    try {
      await _migratePigpenReferences();
      await prefs.setBool('hasMigratedPigpenRefs', true);
    } catch (e) {
      debugPrint('Migration failed: ${e.toString()}');
    }
  }
}

Future<bool> _getIntroCompletedStatus() async {
  final settingsBox = Hive.box('settings');
  return settingsBox.get('introCompleted', defaultValue: false) ?? false;
}

// Data Migration Functions
Future<void> _migratePigpenReferences() async {
  final pigBox = Hive.box<Pig>('pigs');
  final pigpenBox = Hive.box<Pigpen>('pigpens');
  final unassignedPigpen = pigpenBox.values.firstWhere(
    (p) => p.name == "Unassigned",
    orElse: () {
      final newPen = Pigpen(
        name: "Unassigned",
        description: "Pigs not assigned to any specific pigpen",
      );
      pigpenBox.add(newPen);
      return newPen;
    },
  );

  final pigsMap = pigBox.toMap();

  for (final entry in pigsMap.entries) {
    final pigKey = entry.key;
    final pigData = entry.value as Map<dynamic, dynamic>;

    if (pigData['pigpenKey'] != null) continue;

    if (pigData['pigpen'] != null) {
      try {
        final pigpenName = pigData['pigpen'] as String;
        final pigpen = pigpenBox.values.firstWhere(
          (p) => p.name == pigpenName,
        );
        await pigBox.put(
          pigKey,
          Pig(
            tag: pigData['tag'],
            name: pigData['name'],
            breed: pigData['breed'],
            gender: pigData['gender'],
            stage: pigData['stage'],
            weight: pigData['weight'],
            source: pigData['source'],
            dob: pigData['dob'],
            doe: pigData['doe'],
            motherTag: pigData['motherTag'],
            fatherTag: pigData['fatherTag'],
            pigpenKey: pigpen.key,
            notes: pigData['notes'],
            imagePath: pigData['imagePath'],
          ),
        );
      } catch (e) {
        await _assignToUnassigned(pigBox, pigKey, pigData, unassignedPigpen);
      }
    } else {
      await _assignToUnassigned(pigBox, pigKey, pigData, unassignedPigpen);
    }
  }
}

Future<void> _assignToUnassigned(
  Box<Pig> pigBox,
  dynamic pigKey,
  Map<dynamic, dynamic> pigData,
  Pigpen unassignedPigpen,
) async {
  await pigBox.put(
    pigKey,
    Pig(
      tag: pigData['tag'],
      name: pigData['name'],
      breed: pigData['breed'],
      gender: pigData['gender'],
      stage: pigData['stage'],
      weight: pigData['weight'],
      source: pigData['source'],
      dob: pigData['dob'],
      doe: pigData['doe'],
      motherTag: pigData['motherTag'],
      fatherTag: pigData['fatherTag'],
      pigpenKey: unassignedPigpen.key,
      notes: pigData['notes'],
      imagePath: pigData['imagePath'],
    ),
  );
}

// Feeding Schedule Functions
Future<void> _rescheduleAllNotifications() async {
  try {
    final notificationService = NotificationService();
    final feedingScheduleBox = Hive.box<FeedingSchedule>('feedingSchedules');

    for (final schedule in feedingScheduleBox.values) {
      final timeParts = schedule.time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);

      await notificationService.scheduleFeedingNotification(
        id: schedule.notificationId,
        title: 'Feeding Time for ${schedule.pigName}',
        body:
            'Feed ${schedule.quantity} kg of ${schedule.feedType} in ${schedule.pigpenId}',
        time: TimeOfDay(hour: hour, minute: minute),
        date: schedule.date,
        payload: schedule.id, // Pass schedule ID as payload
      );
    }
  } catch (e) {
    debugPrint('Error rescheduling notifications: ${e.toString()}');
  }
}

Future<void> _checkPendingFeedings() async {
  try {
    final now = DateTime.now();
    final box = await Hive.openBox<FeedingSchedule>('feedingSchedules');

    for (final schedule in box.values) {
      if (!schedule.isFeedDeducted) {
        final scheduleDate = DateTime(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
        );
        final today = DateTime(now.year, now.month, now.day);

        // Check if schedule date is today or in the past
        if (scheduleDate.isBefore(today) ||
            scheduleDate.isAtSameMomentAs(today)) {
          final scheduleTime = schedule.timeOfDay;
          final currentTime = TimeOfDay.fromDateTime(now);

          // Check if scheduled time has passed today
          if (isTimePassed(scheduleTime, currentTime)) {
            await schedule.executeFeeding();
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Error checking pending feedings: $e');
  }
}

bool isTimePassed(TimeOfDay scheduledTime, TimeOfDay currentTime) {
  if (scheduledTime.hour < currentTime.hour) return true;
  if (scheduledTime.hour == currentTime.hour &&
      scheduledTime.minute <= currentTime.minute) {
    return true;
  }
  return false;
}

// Main App Widget
class PigCareApp extends StatelessWidget {
  const PigCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PigCare',
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _getIntroCompletedStatus(),
        builder: (context, snapshot) {
          // Always show loading screen first
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }

          // After data is loaded, show appropriate screen
          if (snapshot.hasData) {
            return snapshot.data!
                ? const DashboardScreen(allPigs: [])
                : const IntroScreen();
          }

          // If there's an error, show loading screen as fallback
          return const LoadingScreen();
        },
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.green[700],
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
