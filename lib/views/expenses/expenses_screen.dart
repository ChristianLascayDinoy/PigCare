import 'package:flutter/material.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses Tracking'),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: Text(
          'Expenses Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
