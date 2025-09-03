import 'package:equatable/equatable.dart';

class VideoClip extends Equatable {
  final String sourcePath;
  final String? processedPath; // Path to a processed version (e.g., stabilized)
  final Duration startTimeInSource;
  final Duration endTimeInSource;
  final String uniqueId;

  const VideoClip({
    required this.sourcePath,
    this.processedPath,
    required this.startTimeInSource,
    required this.endTimeInSource,
    required this.uniqueId,
  });

  /// The actual file path that should be used for playback or processing.
  /// Defaults to the processed path if it exists, otherwise the original source.
  String get playablePath => processedPath ?? sourcePath;

  /// The duration of this specific clip segment.
  Duration get duration {
    // If a clip has been processed (e.g., stabilized), its start/end times
    // are relative to the new processed file itself.
    if (processedPath != null) {
      return endTimeInSource;
    }
    // Otherwise, it's a slice of the original source file.
    return endTimeInSource - startTimeInSource;
  }

  /// Creates a copy of this VideoClip but with the given fields replaced with the new values.
  VideoClip copyWith({
    String? sourcePath,
    String? processedPath,
    Duration? startTimeInSource,
    Duration? endTimeInSource,
    String? uniqueId,
  }) {
    return VideoClip(
      sourcePath: sourcePath ?? this.sourcePath,
      processedPath: processedPath ?? this.processedPath,
      startTimeInSource: startTimeInSource ?? this.startTimeInSource,
      endTimeInSource: endTimeInSource ?? this.endTimeInSource,
      uniqueId: uniqueId ?? this.uniqueId,
    );
  }

  @override
  List<Object?> get props => [
    sourcePath,
    processedPath,
    startTimeInSource,
    endTimeInSource,
    uniqueId,
  ];
}
