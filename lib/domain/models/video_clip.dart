import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';

part 'video_clip.g.dart';

@immutable
@HiveType(typeId: 1)
class VideoClip extends TimelineClip with EquatableMixin {
  @HiveField(3)
  final String sourcePath;

  @HiveField(4)
  final String? processedPath;

  @HiveField(5)
  final int sourceDurationInMicroseconds;

  @HiveField(6)
  final int startTimeInSourceInMicroseconds;

  @HiveField(7)
  final int endTimeInSourceInMicroseconds;

  @HiveField(8, defaultValue: 1.0)
  final double speed;

  @HiveField(9, defaultValue: 1.0)
  final double volume;

  @HiveField(10)
  final String? thumbnailPath;

  // --- NEW: Transform Properties for PIP/Overlay ---
  @HiveField(11, defaultValue: 0.5)
  final double offsetX;

  @HiveField(12, defaultValue: 0.5)
  final double offsetY;

  @HiveField(13, defaultValue: 1.0)
  final double scale;

  @HiveField(14, defaultValue: 0.0)
  final double rotation;

  // --- NEW: Transition Properties ---
  // Stores the transition used to enter THIS clip from the previous one.
  @HiveField(15)
  final String? transitionType; // e.g., "fade", "slideleft", "wipeleft"

  @HiveField(16, defaultValue: 0)
  final int transitionDurationMicroseconds;

  VideoClip({
    required super.id,
    required super.startTimeInTimelineInMicroseconds,
    required super.durationInMicroseconds,
    required this.sourcePath,
    required this.sourceDurationInMicroseconds,
    required this.startTimeInSourceInMicroseconds,
    required this.endTimeInSourceInMicroseconds,
    this.processedPath,
    this.speed = 1.0,
    this.volume = 1.0,
    this.thumbnailPath,
    this.offsetX = 0.5,
    this.offsetY = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.transitionType,
    this.transitionDurationMicroseconds = 0,
  });

  String get playablePath => processedPath ?? sourcePath;
  Duration get sourceDuration =>
      Duration(microseconds: sourceDurationInMicroseconds);
  Duration get startTimeInSource =>
      Duration(microseconds: startTimeInSourceInMicroseconds);
  Duration get endTimeInSource =>
      Duration(microseconds: endTimeInSourceInMicroseconds);

  @override
  List<Object?> get props => [
    id,
    startTimeInTimelineInMicroseconds,
    durationInMicroseconds,
    sourcePath,
    processedPath,
    sourceDurationInMicroseconds,
    startTimeInSourceInMicroseconds,
    endTimeInSourceInMicroseconds,
    speed,
    volume,
    thumbnailPath,
    offsetX,
    offsetY,
    scale,
    rotation,
    transitionType,
    transitionDurationMicroseconds,
  ];

  VideoClip copyWith({
    String? id,
    int? startTimeInTimelineInMicroseconds,
    int? durationInMicroseconds,
    String? sourcePath,
    String? processedPath,
    int? sourceDurationInMicroseconds,
    int? startTimeInSourceInMicroseconds,
    int? endTimeInSourceInMicroseconds,
    double? speed,
    double? volume,
    String? thumbnailPath,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotation,
    String? transitionType,
    int? transitionDurationMicroseconds,
  }) {
    return VideoClip(
      id: id ?? this.id,
      startTimeInTimelineInMicroseconds:
          startTimeInTimelineInMicroseconds ??
          this.startTimeInTimelineInMicroseconds,
      durationInMicroseconds:
          durationInMicroseconds ?? this.durationInMicroseconds,
      sourcePath: sourcePath ?? this.sourcePath,
      processedPath: processedPath ?? this.processedPath,
      sourceDurationInMicroseconds:
          sourceDurationInMicroseconds ?? this.sourceDurationInMicroseconds,
      startTimeInSourceInMicroseconds:
          startTimeInSourceInMicroseconds ??
          this.startTimeInSourceInMicroseconds,
      endTimeInSourceInMicroseconds:
          endTimeInSourceInMicroseconds ?? this.endTimeInSourceInMicroseconds,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      transitionType: transitionType ?? this.transitionType,
      transitionDurationMicroseconds:
          transitionDurationMicroseconds ?? this.transitionDurationMicroseconds,
    );
  }

  // --- CRITICAL: TO JSON (SAVING) ---
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'video',
      'sourcePath': sourcePath,
      'startTimeInTimeline': startTimeInTimelineInMicroseconds,
      'duration': durationInMicroseconds,
      'sourceDuration': sourceDurationInMicroseconds,
      'startTimeInSource': startTimeInSourceInMicroseconds,
      'endTimeInSource': endTimeInSourceInMicroseconds,
      'speed': speed,
      'volume': volume,
      'thumbnailPath': thumbnailPath,

      // SAVE THESE FIELDS!
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scale': scale,
      'rotation': rotation,
      'transitionType': transitionType,
      'transitionDuration': transitionDurationMicroseconds,
    };
  }

  // --- CRITICAL: FROM JSON (LOADING) ---
  factory VideoClip.fromJson(Map<String, dynamic> json) {
    return VideoClip(
      id: json['id'],
      sourcePath: json['sourcePath'],
      startTimeInTimelineInMicroseconds: json['startTimeInTimeline'],
      durationInMicroseconds: json['duration'],
      sourceDurationInMicroseconds: json['sourceDuration'] ?? 0,
      startTimeInSourceInMicroseconds: json['startTimeInSource'] ?? 0,
      endTimeInSourceInMicroseconds: json['endTimeInSource'] ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      thumbnailPath: json['thumbnailPath'],

      // LOAD THESE FIELDS!
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.5,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      transitionType: json['transitionType'],
      transitionDurationMicroseconds: json['transitionDuration'] ?? 0,
    );
  }
}
