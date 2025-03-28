import 'package:hive/hive.dart';

part 'event_model.g.dart';

@HiveType(typeId: 4)
class PigEvent {
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
  });

  // Helper method to check if event applies to a specific pig
  bool appliesToPig(String pigTag) => pigTags.contains(pigTag);
  bool get isUpcoming => date.isAfter(DateTime.now());
  bool get isPast => !isUpcoming;
}
