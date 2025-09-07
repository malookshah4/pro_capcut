import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';

@immutable
class VideoClip extends Equatable {
  final String sourcePath;
  final String? processedPath;
  final Duration sourceDuration;
  final Duration startTimeInSource;
  final Duration endTimeInSource;
  final String uniqueId;
  final double speed;
  final List<AudioClip> audioClips;

  const VideoClip({
    required this.sourcePath,
    required this.sourceDuration,
    required this.startTimeInSource,
    required this.endTimeInSource,
    required this.uniqueId,
    this.processedPath,
    this.speed = 1.0,
    this.audioClips = const [],
  });

  String get playablePath => processedPath ?? sourcePath;

  // --- NEW: The missing getter for the clip's original duration from its source ---
  Duration get durationInSource => endTimeInSource - startTimeInSource;

  // The final duration of the clip on the timeline, accounting for speed changes
  Duration get duration {
    if (processedPath != null) {
      // Processed clips are self-contained, so their duration is their full length
      return endTimeInSource;
    }
    // For virtual clips, calculate the duration based on speed
    if (speed <= 0) return durationInSource;
    return Duration(
      microseconds: (durationInSource.inMicroseconds / speed).round(),
    );
  }

  @override
  List<Object?> get props => [
    sourcePath,
    processedPath,
    startTimeInSource,
    endTimeInSource,
    uniqueId,
    speed,
    audioClips,
  ];

  VideoClip copyWith({
    String? sourcePath,
    String? processedPath,
    Duration? sourceDuration,
    bool clearProcessedPath = false,
    Duration? startTimeInSource,
    Duration? endTimeInSource,
    String? uniqueId,
    double? speed,
    List<AudioClip>? audioClips,
  }) {
    return VideoClip(
      sourcePath: sourcePath ?? this.sourcePath,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      processedPath: clearProcessedPath
          ? null
          : processedPath ?? this.processedPath,
      startTimeInSource: startTimeInSource ?? this.startTimeInSource,
      endTimeInSource: endTimeInSource ?? this.endTimeInSource,
      uniqueId: uniqueId ?? this.uniqueId,
      speed: speed ?? this.speed,
      audioClips: audioClips ?? this.audioClips,
    );
  }
}
