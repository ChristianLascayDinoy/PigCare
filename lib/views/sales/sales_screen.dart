import 'package:flutter/material.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Management'),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: Text(
          'Sales Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
