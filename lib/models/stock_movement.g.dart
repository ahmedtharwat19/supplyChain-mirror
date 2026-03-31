// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockMovementAdapter extends TypeAdapter<StockMovement> {
  @override
  final int typeId = 0;

  @override
  StockMovement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockMovement(
      id: fields[0] as String?,
      itemId: fields[1] as String,
      quantity: fields[2] as double,
      unit: fields[3] as String,
      type: fields[4] as String,
      date: fields[5] as Timestamp,
      companyId: fields[6] as String,
      factoryId: fields[7] as String,
      userId: fields[8] as String,
      referenceId: fields[9] as String,
      isSynced: fields[10] as bool,
      lastUpdated: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StockMovement obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.companyId)
      ..writeByte(7)
      ..write(obj.factoryId)
      ..writeByte(8)
      ..write(obj.userId)
      ..writeByte(9)
      ..write(obj.referenceId)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
