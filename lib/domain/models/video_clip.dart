// lib/domain/models/video_clip.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart'; // Import new base class

part 'video_clip.g.dart';

@immutable
@HiveType(typeId: 1) // Keep existing typeId
class VideoClip extends TimelineClip with EquatableMixin {
  @HiveField(3) // Start fields after base class
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

  // Constructor passes timeline info to the 'super' class
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
    );
  }
}
