import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';

part 'audio_clip.g.dart';

@immutable
@HiveType(typeId: 2)
class AudioClip extends TimelineClip with EquatableMixin {
  @HiveField(3)
  final String filePath;

  @HiveField(4, defaultValue: 1.0)
  final double volume;

  // --- NEW: Track where in the source file we start playing ---
  @HiveField(5, defaultValue: 0)
  final int startTimeInSourceInMicroseconds;

  AudioClip({
    required super.id,
    required super.startTimeInTimelineInMicroseconds,
    required super.durationInMicroseconds,
    required this.filePath,
    this.volume = 1.0,
    this.startTimeInSourceInMicroseconds = 0,
  });

  // Helper Getter
  Duration get startTimeInSource =>
      Duration(microseconds: startTimeInSourceInMicroseconds);

  @override
  List<Object?> get props => [
    id,
    startTimeInTimelineInMicroseconds,
    durationInMicroseconds,
    filePath,
    volume,
    startTimeInSourceInMicroseconds,
  ];

  // --- CopyWith for Updates ---
  AudioClip copyWith({
    String? id,
    int? startTimeInTimelineInMicroseconds,
    int? durationInMicroseconds,
    String? filePath,
    double? volume,
    int? startTimeInSourceInMicroseconds,
  }) {
    return AudioClip(
      id: id ?? this.id,
      startTimeInTimelineInMicroseconds:
          startTimeInTimelineInMicroseconds ??
          this.startTimeInTimelineInMicroseconds,
      durationInMicroseconds:
          durationInMicroseconds ?? this.durationInMicroseconds,
      filePath: filePath ?? this.filePath,
      volume: volume ?? this.volume,
      startTimeInSourceInMicroseconds:
          startTimeInSourceInMicroseconds ??
          this.startTimeInSourceInMicroseconds,
    );
  }
}
