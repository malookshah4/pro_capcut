import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class AudioClip extends Equatable {
  /// The path to the processed audio file (e.g., extracted.aac).
  final String filePath;

  /// The unique ID for this clip, used for UI keys.
  final String uniqueId;

  /// The total duration of this audio clip.
  final Duration duration;

  /// The position where this clip starts on the main timeline.
  final Duration startTimeInTimeline;

  const AudioClip({
    required this.filePath,
    required this.uniqueId,
    required this.duration,
    required this.startTimeInTimeline,
  });

  @override
  List<Object?> get props => [
    filePath,
    uniqueId,
    duration,
    startTimeInTimeline,
  ];

  AudioClip copyWith({
    String? filePath,
    String? uniqueId,
    Duration? duration,
    Duration? startTimeInTimeline,
  }) {
    return AudioClip(
      filePath: filePath ?? this.filePath,
      uniqueId: uniqueId ?? this.uniqueId,
      duration: duration ?? this.duration,
      startTimeInTimeline: startTimeInTimeline ?? this.startTimeInTimeline,
    );
  }
}
