import 'package:hive/hive.dart';
import 'pig_model.dart';

part 'pigpen_model.g.dart';

@HiveType(typeId: 0)
class Pigpen extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String description;

  @HiveField(2)
  List<Pig> pigs;

  @HiveField(3) // Add new field
  final int capacity;

  Pigpen({
    required this.name,
    required this.description,
    List<Pig>? pigs,
    this.capacity = 0, // Default to 0 (unlimited)
  }) : pigs = pigs ?? [];

  Pigpen copyWith({
    String? name,
    String? description,
    List<Pig>? pigs,
    int? capacity,
  }) {
    return Pigpen(
      name: name ?? this.name,
      description: description ?? this.description,
      pigs: pigs ?? List.from(this.pigs),
      capacity: capacity ?? this.capacity,
    );
  }

  int get remainingCapacity {
    return capacity == 0 ? -1 : capacity - pigs.length; // -1 means unlimited
  }

  String get capacityStatus {
    if (capacity == 0) return 'Unlimited';
    return '$remainingCapacity of $capacity available';
  }

  // Add this new method to check capacity
  bool get isFull {
    // Capacity 0 means unlimited capacity
    if (capacity == 0) return false;
    return pigs.length >= capacity;
  }

  // Update the addPig method to check capacity
  Future<void> addPig(Pig pig) async {
    if (isFull) {
      throw Exception(
          'Cannot add pig - $name is at full capacity ($capacity pigs)');
    }
    if (containsPigWithTag(pig.tag)) {
      throw Exception('Pig with tag ${pig.tag} already exists in this pigpen');
    }

    pigs.add(pig);
    pig.pigpenKey = key;
    await pig.save();
    await save();
  }

  /// Removes a pig from this pigpen and clears its reference
  Future<void> removePig(Pig pig) async {
    if (!pigs.contains(pig)) return;

    pigs.remove(pig);
    pig.pigpenKey = null;
    await pig.save();
    await save();
  }

  @override
  Future<void> delete() async {
    final box = Hive.box<Pigpen>('pigpens');
    await box.delete(key);
  }

  /// Transfers pigs from another pigpen to this one
  Future<void> transferPigs(List<Pig> pigsToTransfer) async {
    if (capacity > 0 && pigs.length + pigsToTransfer.length > capacity) {
      throw Exception(
          'Cannot transfer ${pigsToTransfer.length} pigs - $name would exceed capacity ($capacity)');
    }

    final box = Hive.box<Pigpen>('pigpens');

    for (final pig in pigsToTransfer) {
      // Remove from current pigpen if it exists
      if (pig.pigpenKey != null) {
        final currentPen = box.get(pig.pigpenKey);
        if (currentPen != null && currentPen != this) {
          await currentPen.removePig(pig);
        }
      }

      // Add to this pigpen if not already present
      if (!containsPigWithTag(pig.tag)) {
        pigs.add(pig);
        pig.pigpenKey = key;
        await pig.save();
      }
    }

    await save();
  }

  /// Gets the count of pigs in this pen
  int get pigCount => pigs.length;

  /// Gets the average weight of pigs in this pen
  double get averageWeight {
    if (pigs.isEmpty) return 0;
    return pigs.map((p) => p.weight).reduce((a, b) => a + b) / pigs.length;
  }

  /// Gets the count of pigs by gender
  Map<String, int> get genderCount {
    final count = {'Male': 0, 'Female': 0};
    for (final pig in pigs) {
      count[pig.gender] = (count[pig.gender] ?? 0) + 1;
    }
    return count;
  }

  /// Checks if the pigpen contains a pig with the given tag
  bool containsPigWithTag(String tag) {
    return pigs.any((pig) => pig.tag == tag);
  }

  /// Gets pigs by stage (Piglet, Weaner, etc.)
  List<Pig> getPigsByStage(String stage) {
    return pigs.where((pig) => pig.stage == stage).toList();
  }

  /// Calculates total feed consumption (if you have feed data)
  /*double calculateDailyFeedConsumption() {
    return pigs.fold(0.0, (sum, pig) => sum + pig.dailyFeedRequirement);
  }*/

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pigpen &&
          runtimeType == other.runtimeType &&
          key == other.key && // Compare by Hive key
          name == other.name &&
          description == other.description;

  @override
  int get hashCode => key.hashCode ^ name.hashCode ^ description.hashCode;

  @override
  String toString() {
    return 'Pigpen{name: $name, description: $description, pigCount: $pigCount}';
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'description': description,
      'pigCount': pigCount,
      'averageWeight': averageWeight,
    };
  }
}
