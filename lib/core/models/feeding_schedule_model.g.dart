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
      id: fields[0] as String?,
      pigId: fields[1] as String,
      pigName: fields[2] as String,
      pigpenId: fields[3] as String,
      feedType: fields[4] as String,
      quantity: fields[5] as double,
      time: fields[6] as String,
      date: fields[7] as DateTime,
      notificationId: fields[8] as int,
      isFeedDeducted: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FeedingSchedule obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pigId)
      ..writeByte(2)
      ..write(obj.pigName)
      ..writeByte(3)
      ..write(obj.pigpenId)
      ..writeByte(4)
      ..write(obj.feedType)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.time)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.notificationId)
      ..writeByte(9)
      ..write(obj.isFeedDeducted);
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
