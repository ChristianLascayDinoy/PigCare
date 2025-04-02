import 'package:hive/hive.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 6) // Unique typeId
class Sale {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String pigTag; // Reference to the pig sold

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String buyer;

  @HiveField(5)
  final String? notes;

  Sale({
    required this.id,
    required this.pigTag,
    required this.amount,
    required this.date,
    required this.buyer,
    this.notes,
  });

  // Helper method to create a copy with updated fields
  Sale copyWith({
    String? id,
    String? pigTag,
    double? amount,
    DateTime? date,
    String? buyer,
    String? notes,
  }) {
    return Sale(
      id: id ?? this.id,
      pigTag: pigTag ?? this.pigTag,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      buyer: buyer ?? this.buyer,
      notes: notes ?? this.notes,
    );
  }
}
