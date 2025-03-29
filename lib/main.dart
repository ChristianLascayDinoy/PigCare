import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pigcare/core/models/feeding_schedule_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/views/dashboard/dashboard_screen.dart';
import 'package:pigcare/core/views/systemlogin/intro_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive
    await _initializeHive();

    // Initialize app data and perform migrations
    await _initializeAppData();

    // Open settings box for intro screen tracking
    await Hive.openBox('settings');

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
    _openBox<Feed>('feedsBox'),
    _openBox<FeedingSchedule>('feedingSchedules'),
    _openBox<PigEvent>('pig_events'),
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

Future<bool> _getIntroCompletedStatus() async {
  final settingsBox = Hive.box('settings');
  return settingsBox.get('introCompleted', defaultValue: false) ?? false;
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
      home: FutureBuilder<bool>(
        future: _getIntroCompletedStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data ?? false
                ? const DashboardScreen()
                : const IntroScreen();
          }
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
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

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Pigpen Management",
      description: "Track all your pigpens and their populations at a glance",
      icon: Icons.home_work,
      color: Colors.green.shade100,
      features: [
        "View total pigpen count",
        "See pigs per pen",
        "Quick status overview"
      ],
    ),
    OnboardingPage(
      title: "Pig Tracking",
      description: "Monitor individual pigs with detailed records",
      icon: Icons.pets,
      color: Colors.blue.shade100,
      features: [
        "Track growth and health",
        "Manage breeding",
        "Individual ID system"
      ],
    ),
    OnboardingPage(
      title: "Farm Operations",
      description: "Complete farm management solution",
      icon: Icons.agriculture,
      color: Colors.orange.shade100,
      features: [
        "Feed management",
        "Event tracking",
        "Expenses & sales",
        "Reports generation"
      ],
    ),
  ];

  void _completeOnboarding() async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('introCompleted', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage].color,
                  Colors.white,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button (top-right)
                if (_currentPage != _pages.length - 1)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      return OnboardingPageContent(page: _pages[index]);
                    },
                  ),
                ),

                // Page indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: Colors.green,
                      dotColor: Colors.grey,
                      spacing: 10,
                      expansionFactor: 3,
                    ),
                  ),
                ),

                // Next/Get Started button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        elevation: 2,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? "Get Started"
                            : "Next",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;

  const OnboardingPageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon illustration
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: Colors.green[800],
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Feature list
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: page.features
                .map((feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}
