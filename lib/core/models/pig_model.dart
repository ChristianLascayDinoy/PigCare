import 'package:hive/hive.dart';
import 'package:pigcare/core/models/pigpen_model.dart';

part 'pig_model.g.dart';

@HiveType(typeId: 1)
class Pig extends HiveObject {
  @HiveField(0)
  final String tag;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String breed;

  @HiveField(3)
  final String gender;

  @HiveField(4)
  final String stage;

  @HiveField(5)
  final double weight;

  @HiveField(6)
  final String source;

  @HiveField(7)
  final String dob;

  @HiveField(8)
  final String doe;

  @HiveField(9)
  final String? motherTag;

  @HiveField(10)
  final String? fatherTag;

  @HiveField(11)
  int? pigpenKey;

  @HiveField(12)
  final String? notes;

  @HiveField(13)
  final String? imagePath;

  String? get pigpen => null;

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
    this.pigpenKey,
    this.notes,
    this.imagePath,
  });

  // Helper method to get pigpen name
  String? getPigpenName(List<Pigpen> allPigpens) {
    if (pigpenKey == null) return null;
    try {
      return allPigpens.firstWhere((p) => p.key == pigpenKey).name;
    } catch (e) {
      return null;
    }
  }

  int get age {
    try {
      DateTime birthDate = DateTime.parse(dob);
      return DateTime.now().difference(birthDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  String getFormattedAge() {
    int days = age;
    if (days < 7) return "$days days old";
    if (days < 30) return "${(days / 7).floor()} weeks old";
    return "${(days / 30).floor()} months old";
  }

  bool get isSexuallyMature => age > 180;

  bool canBeParentOf(Pig offspring) {
    try {
      final parentDob = DateTime.parse(dob);
      final childDob = DateTime.parse(offspring.dob);
      return childDob.isAfter(parentDob);
    } catch (e) {
      return false;
    }
  }

  String get genderSymbol => gender == 'Male' ? '♂' : '♀';
}
