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

  Pigpen({
    required this.name,
    required this.description,
    List<Pig>? pigs,
  }) : pigs = pigs ?? [];

  /// Creates a copy of the pigpen with new values
  Pigpen copyWith({
    String? name,
    String? description,
    List<Pig>? pigs,
  }) {
    return Pigpen(
      name: name ?? this.name,
      description: description ?? this.description,
      pigs: pigs ?? List.from(this.pigs),
    );
  }

  /// Adds a pig to this pigpen and updates its reference
  Future<void> addPig(Pig pig) async {
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

  /// Transfers pigs from another pigpen to this one
  Future<void> transferPigs(List<Pig> pigsToTransfer) async {
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
        await addPig(pig);
      }
    }
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
