import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/event_model.dart';
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
                    'Failed to initialize app: ${e.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
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
  Hive.registerAdapter(PigEventAdapter());

  // Open all Hive boxes with error handling
  await Future.wait([
    _openBox<Pigpen>('pigpens'),
    _openBox<Pig>('pigs'),
    Hive.openBox<Feed>('feeds'),
    _openBox<FeedingSchedule>('feedingSchedules'),
    Hive.openBox<PigEvent>('pig_events'),
  ]);
}

Future<void> _openBox<T>(String boxName) async {
  try {
    await Hive.openBox<T>(boxName);
  } catch (e) {
    debugPrint('Error opening box $boxName: ${e.toString()}');
    // Delete corrupt box and recreate
    await Hive.deleteBoxFromDisk(boxName);
    await Hive.openBox<T>(boxName);
  }
}

Future<void> _initializeAppData() async {
  // Initialize the Unassigned pigpen
  await _initializeUnassignedPigpen();

  // Perform data migrations if needed
  await _performDataMigrations();
}

Future<void> _initializeUnassignedPigpen() async {
  final pigpenBox = Hive.box<Pigpen>('pigpens');

  // Check if Unassigned pigpen exists
  final hasUnassigned = pigpenBox.values.any((p) => p.name == "Unassigned");

  if (!hasUnassigned) {
    // Create with empty pig list
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

Future<void> _migratePigpenReferences() async {
  final pigBox = Hive.box<Pig>('pigs');
  final pigpenBox = Hive.box<Pigpen>('pigpens');

  // Get or create Unassigned pigpen
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
          ),
        );
      } catch (e) {
        // Fallback to Unassigned if pigpen not found
        await _assignToUnassigned(pigBox, pigKey, pigData, unassignedPigpen);
      }
    } else {
      // No pigpen reference, assign to Unassigned
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

class PigCareApp extends StatelessWidget {
  const PigCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PigCare',
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
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
