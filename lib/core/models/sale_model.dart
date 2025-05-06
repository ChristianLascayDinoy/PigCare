// models/sale_model.dart
import 'package:hive/hive.dart';

part 'sale_model.g.dart';

// models/sale_model.dart
@HiveType(typeId: 6)
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

  @HiveField(6) // New field
  final double? weight;

  @HiveField(7) // New field
  final String? buyerContact;

  Sale({
    required this.id,
    required this.pigTag,
    required this.buyerName,
    required this.amount,
    required this.date,
    this.description,
    this.weight,
    this.buyerContact,
  });

  Sale copyWith({
    String? id,
    String? pigTag,
    String? buyerName,
    double? amount,
    DateTime? date,
    String? description,
    double? weight,
    String? buyerContact,
  }) {
    return Sale(
      id: id ?? this.id,
      pigTag: pigTag ?? this.pigTag,
      buyerName: buyerName ?? this.buyerName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      buyerContact: buyerContact ?? this.buyerContact,
    );
  }
}
