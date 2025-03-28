// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PigEventAdapter extends TypeAdapter<PigEvent> {
  @override
  final int typeId = 4;

  @override
  PigEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PigEvent(
      id: fields[0] as String,
      name: fields[1] as String,
      date: fields[2] as DateTime,
      description: fields[3] as String,
      pigTags: (fields[4] as List).cast<String>(),
      eventType: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PigEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.pigTags)
      ..writeByte(5)
      ..write(obj.eventType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PigEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
