// models/sale_model.dart
import 'package:hive/hive.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 6) // Make sure this ID is unique in your app
class Sale {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String pigTag;

  @HiveField(2)
  final String buyerName;

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String? description;

  Sale({
    required this.id,
    required this.pigTag,
    required this.buyerName,
    required this.amount,
    required this.date,
    this.description,
  });

  Sale copyWith({
    String? id,
    String? pigTag,
    String? buyerName,
    double? amount,
    DateTime? date,
    String? description,
  }) {
    return Sale(
      id: id ?? this.id,
      pigTag: pigTag ?? this.pigTag,
      buyerName: buyerName ?? this.buyerName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }
}
