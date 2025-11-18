// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_clip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TextClipAdapter extends TypeAdapter<TextClip> {
  @override
  final int typeId = 3;

  @override
  TextClip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextClip(
      id: fields[0] as String,
      startTimeInTimelineInMicroseconds: fields[1] as int,
      durationInMicroseconds: fields[2] as int,
      text: fields[3] as String,
      style: fields[4] as TextStyleModel,
      offsetX: fields[5] as double,
      offsetY: fields[6] as double,
      scale: fields[7] as double,
      rotation: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TextClip obj) {
    writer
      ..writeByte(9)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.style)
      ..writeByte(5)
      ..write(obj.offsetX)
      ..writeByte(6)
      ..write(obj.offsetY)
      ..writeByte(7)
      ..write(obj.scale)
      ..writeByte(8)
      ..write(obj.rotation)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTimeInTimelineInMicroseconds)
      ..writeByte(2)
      ..write(obj.durationInMicroseconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
