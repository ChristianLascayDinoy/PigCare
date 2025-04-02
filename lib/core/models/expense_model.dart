import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 5) // Use a unique typeId (different from your Pig model)
class Expense {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String category;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String? pigTag; // Optional: link to specific pig

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    this.pigTag,
  });

  // Helper method to create a copy with updated fields
  Expense copyWith({
    String? id,
    String? category,
    double? amount,
    DateTime? date,
    String? description,
    String? pigTag,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      pigTag: pigTag ?? this.pigTag,
    );
  }
}
