// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pigpen_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PigpenAdapter extends TypeAdapter<Pigpen> {
  @override
  final int typeId = 0;

  @override
  Pigpen read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pigpen(
      name: fields[0] as String,
      description: fields[1] as String,
      pigs: (fields[2] as List).cast<Pig>(),
    );
  }

  @override
  void write(BinaryWriter writer, Pigpen obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.pigs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PigpenAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
