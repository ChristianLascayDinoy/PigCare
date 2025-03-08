import 'package:hive/hive.dart';

part 'pig_model.g.dart';

@HiveType(typeId: 1)
class Pig extends HiveObject {
  @HiveField(0)
  String tag;

  @HiveField(1)
  String breed;

  @HiveField(2)
  String gender;

  @HiveField(3)
  String stage;

  @HiveField(4)
  String weight;

  @HiveField(5)
  String dob;

  @HiveField(6)
  String doe;

  @HiveField(7)
  String source;

  @HiveField(8)
  String notes;

  @HiveField(9)
  String? imagePath; // Path for stored image

  Pig({
    required this.tag,
    required this.breed,
    required this.gender,
    required this.stage,
    required this.weight,
    required this.dob,
    required this.doe,
    required this.source,
    required this.notes,
    this.imagePath,
  });
}
