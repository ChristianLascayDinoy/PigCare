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

  /// Creates a deep copy of the pigpen
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
    pigs.add(pig);
    pig.pigpenKey = key;
    await pig.save();
    await save();
  }

  /// Removes a pig from this pigpen and clears its reference
  Future<void> removePig(Pig pig) async {
    pigs.remove(pig);
    pig.pigpenKey = null;
    await pig.save();
    await save();
  }

  /// Transfers pigs from another pigpen to this one
  Future<void> transferPigs(List<Pig> pigsToTransfer) async {
    for (final pig in pigsToTransfer) {
      // Remove from current pigpen if it exists
      if (pig.pigpenKey != null) {
        final currentPen = Hive.box<Pigpen>('pigpens').get(pig.pigpenKey);
        if (currentPen != null) {
          await currentPen.removePig(pig);
        }
      }

      // Add to this pigpen
      await addPig(pig);
    }
  }

  /// Updates the pigpen name and maintains all references
  Future<void> updateName(String newName) async {
    final box = Hive.box<Pigpen>('pigpens');
    final updated = copyWith(name: newName);
    await box.put(key, updated);
  }

  /// Updates the pigpen description
  Future<void> updateDescription(String newDescription) async {
    final box = Hive.box<Pigpen>('pigpens');
    final updated = copyWith(description: newDescription);
    await box.put(key, updated);
  }

  /// Gets the count of pigs in this pen
  int get pigCount => pigs.length;

  /// Gets the average weight of pigs in this pen
  double get averageWeight {
    if (pigs.isEmpty) return 0;
    final total = pigs.fold(0.0, (sum, pig) => sum + pig.weight);
    return total / pigs.length;
  }

  /// Checks if the pigpen contains a pig with the given tag
  bool containsPigWithTag(String tag) {
    return pigs.any((pig) => pig.tag == tag);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pigpen &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          pigs.length == other.pigs.length;

  @override
  int get hashCode =>
      name.hashCode ^ description.hashCode ^ pigs.length.hashCode;

  @override
  String toString() {
    return 'Pigpen{name: $name, description: $description, pigCount: $pigCount}';
  }
}
