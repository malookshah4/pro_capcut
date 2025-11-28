// lib/domain/models/project.dart
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';

part 'project.g.dart'; // This will be regenerated

@HiveType(typeId: 0) // Keep existing typeId
class Project extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime lastModified;

  @HiveField(2) // This field used to be videoClips
  List<EditorTrack> tracks; // <-- THE BIG CHANGE

  @HiveField(3) // This field used to be audioClips (now empty)
  // We leave this field number blank for safety
  @HiveField(4)
  String? thumbnailPath;

  // Field 5 (textClips) is also now empty

  @HiveField(6)
  double? canvasAspectRatio;

  Project({
    required this.id,
    required this.lastModified,
    required this.tracks,
    this.thumbnailPath,
    this.canvasAspectRatio, // <--- CHANGED: Was "double? canvasAspectRatio"
  });

  Project copyWith({
    String? id,
    DateTime? lastModified,
    List<EditorTrack>? tracks,
    String? thumbnailPath,
    double? canvasAspectRatio,
  }) {
    return Project(
      id: id ?? this.id,
      lastModified: lastModified ?? this.lastModified,
      tracks: tracks ?? this.tracks,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      canvasAspectRatio: canvasAspectRatio ?? this.canvasAspectRatio,
    );
  }
}
