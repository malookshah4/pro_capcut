// lib/domain/models/editor_track.dart
import 'package:hive/hive.dart';

part 'editor_track.g.dart'; // This file will be re-generated

// --- THIS IS THE FIX ---

// 1. Give the enum a HiveType ID
@HiveType(typeId: 6) // Use a new, unused ID
enum TrackType {
  // 2. Give each value a HiveField ID
  @HiveField(0)
  video,

  @HiveField(1)
  overlay,

  @HiveField(2)
  audio,

  @HiveField(3)
  text,
}
// --- END OF FIX ---

@HiveType(typeId: 5)
class EditorTrack extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  TrackType type; // Hive now knows how to save this

  @HiveField(2)
  List<dynamic> clips;

  @HiveField(3, defaultValue: false)
  bool locked;

  @HiveField(4, defaultValue: false)
  bool muted;

  @HiveField(5, defaultValue: true)
  bool visible;

  EditorTrack({
    required this.id,
    required this.type,
    required this.clips,
    this.locked = false,
    this.muted = false,
    this.visible = true,
  });
}
