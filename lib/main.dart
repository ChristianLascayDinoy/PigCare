import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pigcare/core/models/feeding_schedule_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/views/dashboard/dashboard_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive
    await _initializeHive();

    // Initialize app data and perform migrations
    await _initializeAppData();

    runApp(const PigCareApp());
  } catch (e) {
    // Handle initialization errors gracefully
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: ${e.toString()}'),
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeHive() async {
  await Hive.initFlutter();

  // Register all Hive adapters
  Hive.registerAdapter(PigpenAdapter());
  Hive.registerAdapter(PigAdapter());
  Hive.registerAdapter(FeedAdapter());
  Hive.registerAdapter(FeedingScheduleAdapter());

  // Open all Hive boxes
  await Future.wait([
    Hive.openBox<Pigpen>('pigpens'),
    Hive.openBox<Pig>('pigs'),
    Hive.openBox<Feed>('feeds'),
    Hive.openBox<FeedingSchedule>('feedingSchedules'),
  ]);
}

Future<void> _initializeAppData() async {
  // Initialize the Unassigned pigpen
  await _ensureUnassignedPigpenExists();

  // Perform data migrations if needed
  await _performDataMigrations();
}

Future<void> _ensureUnassignedPigpenExists() async {
  final pigpenBox = Hive.box<Pigpen>('pigpens');
  final hasUnassigned = pigpenBox.values.any((p) => p.name == "Unassigned");

  if (!hasUnassigned) {
    await pigpenBox.add(Pigpen(
      name: "Unassigned",
      description: "Pigs not assigned to any specific pigpen",
    ));
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

Future<void> _migratePigpenReferences() async {
  final pigBox = Hive.box<Pig>('pigs');
  final pigpenBox = Hive.box<Pigpen>('pigpens');

  // Ensure Unassigned pigpen exists
  final unassignedPigpen = pigpenBox.values.firstWhere(
    (p) => p.name == "Unassigned",
    orElse: () {
      final newPigpen = Pigpen(
          name: "Unassigned",
          description: "Pigs not assigned to any specific pigpen");
      pigpenBox.add(newPigpen);
      return newPigpen;
    },
  );

  // Get raw Hive data to access legacy fields
  final pigsMap = pigBox.toMap();

  for (final entry in pigsMap.entries) {
    final pigKey = entry.key;
    final pigData = entry.value as Map<dynamic, dynamic>;

    // Skip if already migrated
    if (pigData['pigpenKey'] != null) continue;

    // Check for legacy pigpen field
    if (pigData['pigpen'] != null) {
      try {
        final pigpenName = pigData['pigpen'] as String;
        final pigpen = pigpenBox.values.firstWhere(
          (p) => p.name == pigpenName,
        );
        // Update with proper reference
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
            ));
      } catch (e) {
        // Fallback to Unassigned if pigpen not found
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
            ));
      }
    } else {
      // No pigpen reference, assign to Unassigned
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
          ));
    }
  }
}

class PigCareApp extends StatelessWidget {
  const PigCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PigCare',
      theme: _buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
