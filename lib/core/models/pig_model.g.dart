// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pig_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PigAdapter extends TypeAdapter<Pig> {
  @override
  final int typeId = 1;

  @override
  Pig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pig(
      tag: fields[0] as String,
      breed: fields[1] as String,
      gender: fields[2] as String,
      stage: fields[3] as String,
      weight: fields[4] as String,
      dob: fields[5] as String,
      doe: fields[6] as String,
      source: fields[7] as String,
      notes: fields[8] as String,
      imagePath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Pig obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.tag)
      ..writeByte(1)
      ..write(obj.breed)
      ..writeByte(2)
      ..write(obj.gender)
      ..writeByte(3)
      ..write(obj.stage)
      ..writeByte(4)
      ..write(obj.weight)
      ..writeByte(5)
      ..write(obj.dob)
      ..writeByte(6)
      ..write(obj.doe)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
