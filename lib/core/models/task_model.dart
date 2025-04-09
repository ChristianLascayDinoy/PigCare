import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 4)
class PigTask {
  bool get isUpcoming => !isCompleted && date.isAfter(DateTime.now());
  bool get isPast => isCompleted || date.isBefore(DateTime.now());
  bool get canEdit => !isCompleted;

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final List<String> pigTags;

  @HiveField(5)
  final String taskType;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  DateTime? completedDate; // Changed from eventType to taskType

  PigTask({
    required this.id,
    required this.name,
    required this.date,
    required this.description,
    required this.pigTags,
    required this.taskType,
    this.isCompleted = false,
    this.completedDate,
  });

  PigTask copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? description,
    List<String>? pigTags,
    String? taskType,
    bool? isCompleted,
    DateTime? completedDate,
  }) {
    return PigTask(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      description: description ?? this.description,
      pigTags: pigTags ?? this.pigTags,
      taskType: taskType ?? this.taskType,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  // Helper method to check if task applies to a specific pig
  bool appliesToPig(String pigTag) => pigTags.contains(pigTag);
}
