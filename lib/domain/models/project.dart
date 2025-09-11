// lib/domain/models/project.dart
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';

part 'project.g.dart'; // This will be generated

@HiveType(typeId: 0) // Main object, usually typeId 0
class Project extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime lastModified;

  @HiveField(2)
  List<VideoClip> videoClips;

  @HiveField(3)
  List<AudioClip> audioClips;

  @HiveField(4)
  String? thumbnailPath;

  Project({
    required this.id,
    required this.lastModified,
    required this.videoClips,
    required this.audioClips,
    this.thumbnailPath,
  });

  @override
  String toString() {
    return 'Project(id: $id, lastModified: $lastModified, thumbnailPath: $thumbnailPath, videoClips: ${videoClips.length}, audioClips: ${audioClips.length})';
  }
}
