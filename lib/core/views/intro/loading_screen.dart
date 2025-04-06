// lib/core/views/loading/loading_screen.dart
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: child,
                );
              },
              child: Image.asset(
                'lib/assets/images/sample.jpg',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback widget if image fails to load
                  return const Icon(Icons.pets, size: 100, color: Colors.green);
                },
              ),
            ),
            const SizedBox(height: 30),
            // Loading indicator
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 20),
            // Loading text
            Text(
              'Loading PigCare...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
