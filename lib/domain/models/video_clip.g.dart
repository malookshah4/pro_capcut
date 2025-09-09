// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_clip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VideoClipAdapter extends TypeAdapter<VideoClip> {
  @override
  final int typeId = 1;

  @override
  VideoClip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VideoClip(
      sourcePath: fields[0] as String,
      sourceDurationInMicroseconds: fields[2] as int,
      startTimeInSourceInMicroseconds: fields[3] as int,
      endTimeInSourceInMicroseconds: fields[4] as int,
      uniqueId: fields[5] as String,
      processedPath: fields[1] as String?,
      speed: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, VideoClip obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.sourcePath)
      ..writeByte(1)
      ..write(obj.processedPath)
      ..writeByte(2)
      ..write(obj.sourceDurationInMicroseconds)
      ..writeByte(3)
      ..write(obj.startTimeInSourceInMicroseconds)
      ..writeByte(4)
      ..write(obj.endTimeInSourceInMicroseconds)
      ..writeByte(5)
      ..write(obj.uniqueId)
      ..writeByte(6)
      ..write(obj.speed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
