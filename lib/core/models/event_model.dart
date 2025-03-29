import 'package:hive/hive.dart';

part 'event_model.g.dart';

@HiveType(typeId: 4)
class PigEvent {
  bool isCompleted;
  DateTime? completedDate;

  bool get isUpcoming => !isCompleted && date.isAfter(DateTime.now());
  bool get isPast => isCompleted || date.isBefore(DateTime.now());

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
  final String eventType;

  PigEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.description,
    required this.pigTags,
    required this.eventType,
    this.isCompleted = false,
    this.completedDate,
  });

  PigEvent copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? description,
    List<String>? pigTags,
    String? eventType,
    bool? isCompleted,
    DateTime? completedDate,
  }) {
    return PigEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      description: description ?? this.description,
      pigTags: pigTags ?? this.pigTags,
      eventType: eventType ?? this.eventType,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  // Helper method to check if event applies to a specific pig
  bool appliesToPig(String pigTag) => pigTags.contains(pigTag);
}
