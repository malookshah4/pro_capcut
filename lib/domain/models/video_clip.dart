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
    );
  }
}
