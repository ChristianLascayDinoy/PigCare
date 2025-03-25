import 'package:hive/hive.dart';

part 'pig_model.g.dart';

@HiveType(typeId: 1)
class Pig extends HiveObject {
  @HiveField(0)
  String tag; // Unique ID

  @HiveField(1)
  String? name; // Optional Unique Name

  @HiveField(2)
  String breed; // Breed of the pig

  @HiveField(3)
  String gender; // Male / Female

  @HiveField(4)
  String stage; // Pig growth stage

  @HiveField(5)
  double weight; // Weight in kg

  @HiveField(6)
  String source; // Purchased / Born on Farm / Other

  @HiveField(7)
  String dob; // Date of Birth (String format)

  @HiveField(8)
  String doe; // Date of Entry (String format)

  @HiveField(9)
  String? motherTag; // Mother's Tag Number (Optional)

  @HiveField(10)
  String? fatherTag; // Father's Tag Number (Optional)

  @HiveField(11)
  String? pigpen; // Assigned Pigpen (or "Unassigned")

  @HiveField(12)
  String? notes; // Additional notes

  @HiveField(13)
  String? imagePath; // Path for stored image

  Pig({
    required this.tag,
    this.name,
    required this.breed,
    required this.gender,
    required this.stage,
    required this.weight,
    required this.source,
    required this.dob,
    required this.doe,
    this.motherTag,
    this.fatherTag,
    this.pigpen,
    this.notes,
    this.imagePath,
  });

  /// **Calculate Age in Days**
  int get age {
    try {
      DateTime birthDate = DateTime.parse(dob);
      return DateTime.now().difference(birthDate).inDays;
    } catch (e) {
      return 0; // Default to 0 if parsing fails
    }
  }

  /// **Convert Age to Weeks/Months**
  String getFormattedAge() {
    int days = age;
    if (days < 7) {
      return "$days days old";
    } else if (days < 30) {
      return "${(days / 7).floor()} weeks old";
    } else {
      return "${(days / 30).floor()} months old";
    }
  }
}
