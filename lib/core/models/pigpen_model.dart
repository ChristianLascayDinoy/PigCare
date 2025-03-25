import 'package:hive/hive.dart';
import 'pig_model.dart';

part 'pigpen_model.g.dart';

@HiveType(typeId: 0)
class Pigpen extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String description;

  @HiveField(2)
  List<Pig> pigs;

  Pigpen({
    required this.name,
    required this.description,
    this.pigs = const [],
  });

  // Add this method to easily save changes
  Future<void> saveChanges() async {
    await save();
  }
}
