import 'package:equatable/equatable.dart';

class VideoClip extends Equatable {
  final String sourcePath;
  final String? processedPath; // Path to a processed version (e.g., stabilized)
  final Duration startTimeInSource;
  final Duration endTimeInSource;
  final String uniqueId;
  final double speed;

  const VideoClip({
    required this.sourcePath,
    this.processedPath,
    required this.startTimeInSource,
    required this.endTimeInSource,
    required this.uniqueId,
    this.speed = 1.0,
  });

  /// The actual file path that should be used for playback or processing.
  /// Defaults to the processed path if it exists, otherwise the original source.
  String get playablePath => processedPath ?? sourcePath;

  /// The duration of this specific clip segment.
  Duration get duration {
    // If the clip has been processed (e.g., for speed), its start/end times
    // are relative to the new file, so we don't divide by speed again.
    if (processedPath != null) {
      return endTimeInSource - startTimeInSource;
    }
    // For a virtual clip from the original source, calculate its new duration.
    final originalDuration = endTimeInSource - startTimeInSource;
    if (speed <= 0) return originalDuration; // Avoid division by zero
    return Duration(
      microseconds: (originalDuration.inMicroseconds / speed).round(),
    );
  }

  /// Creates a copy of this VideoClip but with the given fields replaced with the new values.
  VideoClip copyWith({
    String? sourcePath,
    String? processedPath,
    Duration? startTimeInSource,
    Duration? endTimeInSource,
    String? uniqueId,
    double? speed,
  }) {
    return VideoClip(
      sourcePath: sourcePath ?? this.sourcePath,
      processedPath: processedPath ?? this.processedPath,
      startTimeInSource: startTimeInSource ?? this.startTimeInSource,
      endTimeInSource: endTimeInSource ?? this.endTimeInSource,
      uniqueId: uniqueId ?? this.uniqueId,
      speed: speed ?? this.speed,
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
  ];
}
