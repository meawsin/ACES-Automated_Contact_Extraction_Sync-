// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanRecordAdapter extends TypeAdapter<ScanRecord> {
  @override
  final int typeId = 0;

  @override
  ScanRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanRecord(
      name:         fields[0] as String,
      organization: fields[1] as String?,
      designation:  fields[2] as String?,
      scannedAt:    fields[3] as DateTime,
      isSynced:     fields[4] as bool,
      phone:        fields[5] as String,
      email:        fields[6] as String,
      // BUG FIX: New fields use ?? '' so old records without them load fine.
      telephone:    fields[7] as String? ?? '',
      fax:          fields[8] as String? ?? '',
      address:      fields[9] as String? ?? '',
      links:        fields[10] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ScanRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.organization)
      ..writeByte(2)
      ..write(obj.designation)
      ..writeByte(3)
      ..write(obj.scannedAt)
      ..writeByte(4)
      ..write(obj.isSynced)
      ..writeByte(5)
      ..write(obj.phone)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.telephone)
      ..writeByte(8)
      ..write(obj.fax)
      ..writeByte(9)
      ..write(obj.address)
      ..writeByte(10)
      ..write(obj.links);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}