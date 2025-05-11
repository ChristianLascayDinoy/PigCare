import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'feed_model.g.dart';

@HiveType(typeId: 2)
class Feed extends HiveObject {
  @HiveField(0)
  final String id; // Unique identifier

  @HiveField(1)
  String name;

  @HiveField(2)
  double quantity; // Initial stock in kg

  @HiveField(3)
  double remainingQuantity; // Tracks remaining feed

  @HiveField(4)
  double price; // Cost per kg

  @HiveField(5)
  DateTime purchaseDate;

  @HiveField(6)
  String supplier; // New field for supplier/store name

  @HiveField(7)
  String brand; // New field for feed

  @HiveField(8)
  String? expenseId;

  Feed({
    String? id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.purchaseDate,
    required this.supplier,
    required this.brand,
    this.expenseId,
  })  : id = id ?? const Uuid().v4(),
        remainingQuantity = quantity; // Initialize remaining stock

  Feed copyWith({
    String? id,
    String? name,
    double? quantity,
    double? price,
    DateTime? purchaseDate,
    String? supplier,
    String? brand,
    String? expenseId,
  }) {
    return Feed(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplier: supplier ?? this.supplier,
      brand: brand ?? this.brand,
      expenseId: expenseId ?? this.expenseId,
    );
  }

  // In feed_model.dart
  void deductFeed(double amount) {
    if (amount <= 0) throw Exception('Invalid deduction amount');
    if (amount > remainingQuantity)
      throw Exception('Not enough feed available');

    remainingQuantity -= amount;
    if (remainingQuantity < 0) remainingQuantity = 0;
  }
}
