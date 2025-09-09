// lib/domain/models/video_clip.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'video_clip.g.dart';

@immutable
@HiveType(typeId: 1)
class VideoClip extends Equatable {
  @HiveField(0)
  final String sourcePath;

  @HiveField(1)
  final String? processedPath;

  @HiveField(2)
  final int sourceDurationInMicroseconds;

  @HiveField(3)
  final int startTimeInSourceInMicroseconds;

  @HiveField(4)
  final int endTimeInSourceInMicroseconds;

  @HiveField(5)
  final String uniqueId;

  @HiveField(6)
  final double speed;

  // --- THIS CONSTRUCTOR IS NOW CORRECTED ---
  const VideoClip({
    required this.sourcePath,
    required this.sourceDurationInMicroseconds,
    required this.startTimeInSourceInMicroseconds,
    required this.endTimeInSourceInMicroseconds,
    required this.uniqueId,
    this.processedPath,
    this.speed = 1.0,
  });

  Duration get sourceDuration =>
      Duration(microseconds: sourceDurationInMicroseconds);
  Duration get startTimeInSource =>
      Duration(microseconds: startTimeInSourceInMicroseconds);
  Duration get endTimeInSource =>
      Duration(microseconds: endTimeInSourceInMicroseconds);

  String get playablePath => processedPath ?? sourcePath;
  Duration get durationInSource => endTimeInSource - startTimeInSource;
  Duration get duration {
    if (processedPath != null) {
      return endTimeInSource;
    }
    if (speed <= 0) return durationInSource;
    return Duration(
      microseconds: (durationInSource.inMicroseconds / speed).round(),
    );
  }

  @override
  List<Object?> get props => [
    sourcePath,
    processedPath,
    sourceDurationInMicroseconds,
    startTimeInSourceInMicroseconds,
    endTimeInSourceInMicroseconds,
    uniqueId,
    speed,
  ];

  VideoClip copyWith({
    String? sourcePath,
    String? processedPath,
    int? sourceDurationInMicroseconds,
    bool clearProcessedPath = false,
    int? startTimeInSourceInMicroseconds,
    int? endTimeInSourceInMicroseconds,
    String? uniqueId,
    double? speed,
  }) {
    return VideoClip(
      sourcePath: sourcePath ?? this.sourcePath,
      sourceDurationInMicroseconds:
          sourceDurationInMicroseconds ?? this.sourceDurationInMicroseconds,
      processedPath: clearProcessedPath
          ? null
          : (processedPath ?? this.processedPath),
      startTimeInSourceInMicroseconds:
          startTimeInSourceInMicroseconds ??
          this.startTimeInSourceInMicroseconds,
      endTimeInSourceInMicroseconds:
          endTimeInSourceInMicroseconds ?? this.endTimeInSourceInMicroseconds,
      uniqueId: uniqueId ?? this.uniqueId,
      speed: speed ?? this.speed,
    );
  }
}
