import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Events Management'),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: Text(
          'Events Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
