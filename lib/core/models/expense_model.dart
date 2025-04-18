// models/expense_model.dart
import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 5) // Make sure this ID is unique in your app
class Expense {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final List<String> pigTags;

  @HiveField(6)
  final String? description;

  @HiveField(7)
  final String? feedId;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    required this.pigTags,
    this.description,
    this.feedId,
  });

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    String? category,
    DateTime? date,
    List<String>? pigTags,
    String? description,
    String? feedId,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      pigTags: pigTags ?? this.pigTags,
      description: description ?? this.description,
      feedId: feedId ?? this.feedId,
    );
  }
}
