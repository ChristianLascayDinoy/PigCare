// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feeding_schedule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FeedingScheduleAdapter extends TypeAdapter<FeedingSchedule> {
  @override
  final int typeId = 3;

  @override
  FeedingSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FeedingSchedule(
      pigId: fields[0] as String,
      pigpenId: fields[1] as String,
      feedType: fields[2] as String,
      quantity: fields[3] as double,
      time: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FeedingSchedule obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.pigId)
      ..writeByte(1)
      ..write(obj.pigpenId)
      ..writeByte(2)
      ..write(obj.feedType)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.time);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedingScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
