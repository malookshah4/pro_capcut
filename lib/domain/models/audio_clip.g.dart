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
      id: fields[0] as String,
      startTimeInTimelineInMicroseconds: fields[1] as int,
      durationInMicroseconds: fields[2] as int,
      filePath: fields[3] as String,
      volume: fields[4] == null ? 1.0 : fields[4] as double,
      startTimeInSourceInMicroseconds: fields[5] == null ? 0 : fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AudioClip obj) {
    writer
      ..writeByte(6)
      ..writeByte(3)
      ..write(obj.filePath)
      ..writeByte(4)
      ..write(obj.volume)
      ..writeByte(5)
      ..write(obj.startTimeInSourceInMicroseconds)
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
      other is AudioClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
