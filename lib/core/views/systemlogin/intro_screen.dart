import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../dashboard/dashboard_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  void _proceed(BuildContext context) {
    final settingsBox = Hive.box('settingsBox');
    settingsBox.put('hasSeenIntro', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(child: Image.asset('assets/images/pig_logo.png', height: 150)),
          const SizedBox(height: 20),
          const Text(
            "🐷 Welcome to PigCare App",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              "Manage your pig farm efficiently with PigCare. Keep track of pigs, feeds, events, and expenses.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _proceed(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text("Proceed", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
