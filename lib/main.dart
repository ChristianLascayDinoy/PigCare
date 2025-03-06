import 'package:flutter/material.dart';
import 'views/dashboard/dashboard_screen.dart';

void main() {
  runApp(const PigCareApp());
}

class PigCareApp extends StatelessWidget {
  const PigCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PigCare',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(),
    );
  }
}
