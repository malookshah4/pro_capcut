// lib/bloc/editor_state.dart

part of 'editor_bloc.dart';

abstract class EditorState extends Equatable {
  const EditorState();
  @override
  List<Object?> get props => [];
}

class EditorInitial extends EditorState {}

class EditorLoaded extends EditorState {
  final Project project;
  final bool isPlaying;
  final Duration videoPosition;
  final String? selectedTrackId;
  final String? selectedClipId;
  final ProcessingType? processingType;
  final double processingProgress;
  // --- NEW: Forces rebuilds when data inside the project changes ---
  final int version;

  const EditorLoaded({
    required this.project,
    this.isPlaying = false,
    this.videoPosition = Duration.zero,
    this.selectedTrackId,
    this.selectedClipId,
    this.processingType,
    this.processingProgress = 0.0,
    this.version = 0,
  });

  // Helper getter for the main video track
  EditorTrack get videoTrack =>
      project.tracks.firstWhere((t) => t.type == TrackType.video);

  // Helper getter for the project's total duration
  Duration get videoDuration {
    if (videoTrack.clips.isEmpty) return Duration.zero;
    // Calculate total duration from the main video track
    return videoTrack.clips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );
  }

  bool get isProcessing => processingType != null;

  EditorLoaded copyWith({
    Project? project,
    bool? isPlaying,
    Duration? videoPosition,
    String? selectedTrackId,
    bool clearSelectedTrackId = false,
    String? selectedClipId,
    bool clearSelectedClipId = false,
    ProcessingType? processingType,
    bool clearProcessing = false,
    double? processingProgress,
    int? version, // Add version to copyWith
  }) {
    return EditorLoaded(
      project: project ?? this.project,
      isPlaying: isPlaying ?? this.isPlaying,
      videoPosition: videoPosition ?? this.videoPosition,
      selectedTrackId: clearSelectedTrackId
          ? null
          : selectedTrackId ?? this.selectedTrackId,
      selectedClipId: clearSelectedClipId
          ? null
          : selectedClipId ?? this.selectedClipId,
      processingType: clearProcessing
          ? null
          : processingType ?? this.processingType,
      processingProgress: processingProgress ?? this.processingProgress,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    project,
    isPlaying,
    videoPosition,
    selectedTrackId,
    selectedClipId,
    processingType,
    processingProgress,
    version, // Include version in props for Equatable
  ];
}

enum ProcessingType { stabilization, aiEnhance, noiseReduction, export }
