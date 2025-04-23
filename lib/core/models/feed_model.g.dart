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
      id: fields[0] as String?,
      name: fields[1] as String,
      quantity: fields[2] as double,
      price: fields[4] as double,
      purchaseDate: fields[5] as DateTime,
      supplier: fields[6] as String,
      brand: fields[7] as String,
      expenseId: fields[8] as String?,
    )..remainingQuantity = fields[3] as double;
  }

  @override
  void write(BinaryWriter writer, Feed obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.remainingQuantity)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.purchaseDate)
      ..writeByte(6)
      ..write(obj.supplier)
      ..writeByte(7)
      ..write(obj.brand)
      ..writeByte(8)
      ..write(obj.expenseId);
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
