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
      final birthDate = DateTime.parse(dob);
      return DateTime.now().difference(birthDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  String getFormattedAge() {
    final days = age;
    if (days < 7) return "$days days";
    if (days < 30) return "${(days / 7).floor()} weeks";
    if (days < 365) return "${(days / 30).floor()} months";
    return "${(days / 365).floor()} years";
  }

  bool get isSexuallyMature {
    return age > 180; // Approximately 6 months
  }

  String get genderSymbol => gender == 'Male' ? '♂' : '♀';

  Future<void> assignToPigpen(Pigpen pigpen) async {
    // Remove from current pen if exists
    if (pigpenKey != null) {
      final currentPen = Hive.box<Pigpen>('pigpens').get(pigpenKey);
      if (currentPen != null) {
        currentPen.pigs.removeWhere((p) => p.tag == tag);
        await currentPen.save();
      }
    }

    // Add to new pen
    pigpenKey = pigpen.key;
    pigpen.pigs.add(this);
    await pigpen.save();
    await save();
  }

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'name': name,
      'breed': breed,
      'gender': gender,
      'stage': stage,
      'weight': weight,
      'source': source,
      'dob': dob,
      'doe': doe,
      'motherTag': motherTag,
      'fatherTag': fatherTag,
      'pigpenKey': pigpenKey,
      'notes': notes,
      'imagePath': imagePath,
    };
  }

  factory Pig.fromJson(Map<String, dynamic> json) {
    return Pig(
      tag: json['tag'],
      name: json['name'],
      breed: json['breed'],
      gender: json['gender'],
      stage: json['stage'],
      weight: json['weight'],
      source: json['source'],
      dob: json['dob'],
      doe: json['doe'],
      motherTag: json['motherTag'],
      fatherTag: json['fatherTag'],
      pigpenKey: json['pigpenKey'],
      notes: json['notes'],
      imagePath: json['imagePath'],
    );
  }

  List<Pig> getOffspring(List<Pig> allPigs) {
    return allPigs
        .where((pig) => pig.motherTag == this.tag || pig.fatherTag == this.tag)
        .toList();
  }

  Pig? getMother(List<Pig> allPigs) {
    return motherTag != null
        ? allPigs.firstWhereOrNull((pig) => pig.tag == motherTag)
        : null;
  }

  Pig? getFather(List<Pig> allPigs) {
    return fatherTag != null
        ? allPigs.firstWhereOrNull((pig) => pig.tag == fatherTag)
        : null;
  }

  bool canBeParentOf(Pig potentialChild) {
    try {
      final parentDob = DateTime.parse(dob);
      final childDob = DateTime.parse(potentialChild.dob);
      return childDob.isAfter(parentDob);
    } catch (e) {
      return false;
    }
  }

  // ===============================
  // New Logic: Estimated Weight & Stage
  // ===============================
  double get estimatedWeight {
    final ageInDays = age;

    if (ageInDays <= 21) return _lerp(1.5, 7, ageInDays / 21);
    if (ageInDays <= 56) return _lerp(7, 25, (ageInDays - 21) / 35);
    if (ageInDays <= 112) return _lerp(25, 60, (ageInDays - 56) / 56);
    if (ageInDays <= 180) return _lerp(60, 100, (ageInDays - 112) / 68);
    return 100 + (ageInDays - 180) * 0.5;
  }

  String get estimatedStage {
    final ageInDays = age;

    if (ageInDays <= 21) return 'Piglet';
    if (ageInDays <= 56) return 'Weaner';
    if (ageInDays <= 112) return 'Grower';
    if (ageInDays <= 180) return 'Finisher';
    return gender == 'Male' ? 'Boar' : 'Sow';
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
