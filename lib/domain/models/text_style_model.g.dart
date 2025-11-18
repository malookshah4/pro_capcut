// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_style_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TextStyleModelAdapter extends TypeAdapter<TextStyleModel> {
  @override
  final int typeId = 7;

  @override
  TextStyleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextStyleModel(
      fontName: fields[0] as String,
      fontSize: fields[1] as double,
      primaryColor: fields[2] as int,
      strokeColor: fields[3] as int,
      strokeWidth: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TextStyleModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.fontName)
      ..writeByte(1)
      ..write(obj.fontSize)
      ..writeByte(2)
      ..write(obj.primaryColor)
      ..writeByte(3)
      ..write(obj.strokeColor)
      ..writeByte(4)
      ..write(obj.strokeWidth);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextStyleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
