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
  final int version;
  final bool isExporting;

  // --- NEW: Undo/Redo Stacks ---
  // We store copies of the 'Project' object.
  final List<Project> undoStack;
  final List<Project> redoStack;

  const EditorLoaded({
    required this.project,
    this.isPlaying = false,
    this.videoPosition = Duration.zero,
    this.selectedTrackId,
    this.selectedClipId,
    this.processingType,
    this.processingProgress = 0.0,
    this.version = 0,
    this.isExporting = false,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  EditorTrack get videoTrack =>
      project.tracks.firstWhere((t) => t.type == TrackType.video);

  Duration get videoDuration {
    if (videoTrack.clips.isEmpty) return Duration.zero;
    return videoTrack.clips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );
  }

  bool get isProcessing => processingType != null;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

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
    int? version,
    bool? isExporting,
    List<Project>? undoStack,
    List<Project>? redoStack,
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
      isExporting: isExporting ?? this.isExporting,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
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
    version,
    undoStack
        .length, // Only track length for equatable to avoid heavy comparisons
    redoStack.length,
  ];
}

enum ProcessingType { stabilization, aiEnhance, noiseReduction, export, none }
