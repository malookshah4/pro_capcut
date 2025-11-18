// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_track.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EditorTrackAdapter extends TypeAdapter<EditorTrack> {
  @override
  final int typeId = 5;

  @override
  EditorTrack read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EditorTrack(
      id: fields[0] as String,
      type: fields[1] as TrackType,
      clips: (fields[2] as List).cast<dynamic>(),
      locked: fields[3] == null ? false : fields[3] as bool,
      muted: fields[4] == null ? false : fields[4] as bool,
      visible: fields[5] == null ? true : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, EditorTrack obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.clips)
      ..writeByte(3)
      ..write(obj.locked)
      ..writeByte(4)
      ..write(obj.muted)
      ..writeByte(5)
      ..write(obj.visible);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorTrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrackTypeAdapter extends TypeAdapter<TrackType> {
  @override
  final int typeId = 6;

  @override
  TrackType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrackType.video;
      case 1:
        return TrackType.overlay;
      case 2:
        return TrackType.audio;
      case 3:
        return TrackType.text;
      default:
        return TrackType.video;
    }
  }

  @override
  void write(BinaryWriter writer, TrackType obj) {
    switch (obj) {
      case TrackType.video:
        writer.writeByte(0);
        break;
      case TrackType.overlay:
        writer.writeByte(1);
        break;
      case TrackType.audio:
        writer.writeByte(2);
        break;
      case TrackType.text:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
