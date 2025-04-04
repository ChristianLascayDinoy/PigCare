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

  Feed({
    required this.name,
    required this.quantity,
    required this.price,
    required this.purchaseDate,
  }) : remainingQuantity = quantity; // Initialize remaining stock

  void deductFeed(double amount) {
    remainingQuantity -= amount;
    if (remainingQuantity < 0) {
      remainingQuantity = 0; // Prevent negative stock
    }
    save(); // Save the update to Hive
  }
}
