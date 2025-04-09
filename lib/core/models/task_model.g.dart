// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PigTaskAdapter extends TypeAdapter<PigTask> {
  @override
  final int typeId = 4;

  @override
  PigTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PigTask(
      id: fields[0] as String,
      name: fields[1] as String,
      date: fields[2] as DateTime,
      description: fields[3] as String,
      pigTags: (fields[4] as List).cast<String>(),
      taskType: fields[5] as String,
      isCompleted: fields[6] as bool,
      completedDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PigTask obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.taskType)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.completedDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PigTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
