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
      pigName: fields[1] as String,
      pigpenId: fields[2] as String,
      feedType: fields[3] as String,
      quantity: fields[4] as double,
      time: fields[5] as String,
      date: fields[6] as DateTime,
      notificationId: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FeedingSchedule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.pigId)
      ..writeByte(1)
      ..write(obj.pigName)
      ..writeByte(2)
      ..write(obj.pigpenId)
      ..writeByte(3)
      ..write(obj.feedType)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.time)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.notificationId);
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
