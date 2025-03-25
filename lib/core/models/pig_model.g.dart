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
      name: fields[1] as String?,
      breed: fields[2] as String,
      gender: fields[3] as String,
      stage: fields[4] as String,
      weight: fields[5] as double,
      source: fields[6] as String,
      dob: fields[7] as String,
      doe: fields[8] as String,
      motherTag: fields[9] as String?,
      fatherTag: fields[10] as String?,
      pigpen: fields[11] as String?,
      notes: fields[12] as String?,
      imagePath: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Pig obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.tag)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.breed)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.stage)
      ..writeByte(5)
      ..write(obj.weight)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.dob)
      ..writeByte(8)
      ..write(obj.doe)
      ..writeByte(9)
      ..write(obj.motherTag)
      ..writeByte(10)
      ..write(obj.fatherTag)
      ..writeByte(11)
      ..write(obj.pigpen)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
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
