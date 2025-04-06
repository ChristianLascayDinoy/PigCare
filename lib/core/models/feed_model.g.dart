// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FeedAdapter extends TypeAdapter<Feed> {
  @override
  final int typeId = 2;

  @override
  Feed read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Feed(
      name: fields[0] as String,
      quantity: fields[1] as double,
      price: fields[3] as double,
      purchaseDate: fields[4] as DateTime,
      supplier: fields[5] as String,
      brand: fields[6] as String,
    )..remainingQuantity = fields[2] as double;
  }

  @override
  void write(BinaryWriter writer, Feed obj) {
    writer
      ..writeByte(7) // Updated to 7 fields
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.remainingQuantity)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.purchaseDate)
      ..writeByte(5)
      ..write(obj.supplier)
      ..writeByte(6)
      ..write(obj.brand);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
