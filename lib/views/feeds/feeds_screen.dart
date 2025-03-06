import 'package:flutter/material.dart';

class FeedsScreen extends StatelessWidget {
  const FeedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feed Management'),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: Text(
          'Feeds Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
