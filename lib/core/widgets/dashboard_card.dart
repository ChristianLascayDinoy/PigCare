import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String imagePath; // Now using imagePath instead of IconData
  final VoidCallback onTap;
  final int? count;

  const DashboardCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image instead of Icon
              Image.asset(
                imagePath,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (count != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
