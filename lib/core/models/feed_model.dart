import 'package:hive/hive.dart';

part 'feed_model.g.dart';

@HiveType(typeId: 2)
class Feed extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double quantity; // Initial stock in kg

  @HiveField(2)
  double remainingQuantity; // Tracks remaining feed

  @HiveField(3)
  double price; // Cost per kg

  @HiveField(4)
  DateTime purchaseDate;

  @HiveField(5)
  String supplier; // New field for supplier/store name

  @HiveField(6)
  String brand; // New field for feed

  @HiveField(7)
  String? expenseId;

  Feed({
    required this.name,
    required this.quantity,
    required this.price,
    required this.purchaseDate,
    required this.supplier,
    required this.brand,
    this.expenseId,
  }) : remainingQuantity = quantity; // Initialize remaining stock

  Feed copyWith({
    String? name,
    double? quantity,
    double? price,
    DateTime? purchaseDate,
    String? supplier,
    String? brand,
    String? expenseId,
  }) {
    return Feed(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplier: supplier ?? this.supplier,
      brand: brand ?? this.brand,
      expenseId: expenseId ?? this.expenseId,
    );
  }

  void deductFeed(double amount) {
    remainingQuantity -= amount;
    if (remainingQuantity < 0) {
      remainingQuantity = 0; // Prevent negative stock
    }
    save(); // Save the update to Hive
  }
}
