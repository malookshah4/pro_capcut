// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_clip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioClipAdapter extends TypeAdapter<AudioClip> {
  @override
  final int typeId = 2;

  @override
  AudioClip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioClip(
      filePath: fields[0] as String,
      uniqueId: fields[1] as String,
      durationInMicroseconds: fields[2] as int,
      startTimeInTimelineInMicroseconds: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AudioClip obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.uniqueId)
      ..writeByte(2)
      ..write(obj.durationInMicroseconds)
      ..writeByte(3)
      ..write(obj.startTimeInTimelineInMicroseconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
