part of 'editor_bloc.dart'; // --- This is now the only directive in the file ---

enum ProcessingType {
  stabilization,
  aiEnhance,
  noiseReduction,
  split,
  export,
  speed,
}

abstract class EditorState extends Equatable {
  const EditorState();
  @override
  List<Object?> get props => [];
}

class EditorInitial extends EditorState {}

class EditorLoaded extends EditorState {
  final List<List<VideoClip>> timelineHistory;
  final int historyIndex;
  final bool isPlaying;
  final int? selectedClipIndex;
  final Duration videoPosition;
  final Duration videoDuration;

  const EditorLoaded({
    required this.timelineHistory,
    required this.historyIndex,
    required this.isPlaying,
    this.selectedClipIndex,
    this.videoPosition = Duration.zero,
    this.videoDuration = Duration.zero,
  });

  List<VideoClip> get currentClips => timelineHistory[historyIndex];
  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < timelineHistory.length - 1;

  EditorLoaded copyWith({
    List<List<VideoClip>>? timelineHistory,
    int? historyIndex,
    bool? isPlaying,
    int? selectedClipIndex,
    bool deselectClip = false,
    Duration? videoPosition,
    Duration? videoDuration,
  }) {
    return EditorLoaded(
      timelineHistory: timelineHistory ?? this.timelineHistory,
      historyIndex: historyIndex ?? this.historyIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      videoPosition: videoPosition ?? this.videoPosition,
      videoDuration: videoDuration ?? this.videoDuration,
      selectedClipIndex: deselectClip
          ? null
          : (selectedClipIndex ?? this.selectedClipIndex),
    );
  }

  @override
  List<Object?> get props => [
    timelineHistory,
    historyIndex,
    isPlaying,
    selectedClipIndex,
    videoDuration,
    videoPosition,
  ];
}

class EditorProcessing extends EditorLoaded {
  final double progress;
  final ProcessingType type;

  const EditorProcessing({
    required super.timelineHistory,
    required super.historyIndex,
    required super.isPlaying,
    super.selectedClipIndex,
    required this.progress,
    required this.type,
  });

  @override
  List<Object?> get props => [
    timelineHistory,
    historyIndex,
    isPlaying,
    selectedClipIndex,
    progress,
    type,
  ];
}
