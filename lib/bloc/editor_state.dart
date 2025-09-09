part of 'editor_bloc.dart';

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
  final String projectId;
  final List<List<VideoClip>> timelineHistory;
  final int historyIndex;
  final bool isPlaying;
  final int? selectedClipIndex;
  final Duration videoPosition;
  final Duration videoDuration;
  final List<VideoClip>? liveClips;
  final List<AudioClip> audioClips;

  const EditorLoaded({
    required this.projectId,
    required this.timelineHistory,
    required this.historyIndex,
    required this.isPlaying,
    this.selectedClipIndex,
    this.videoPosition = Duration.zero,
    this.videoDuration = Duration.zero,
    this.liveClips,
    this.audioClips = const [],
  });

  List<VideoClip> get currentClips => timelineHistory[historyIndex];
  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < timelineHistory.length - 1;
  List<VideoClip> get liveCurrentClip =>
      liveClips ?? timelineHistory[historyIndex];

  EditorLoaded copyWith({
    String? projectId,
    List<List<VideoClip>>? timelineHistory,
    int? historyIndex,
    bool? isPlaying,
    int? selectedClipIndex,
    bool deselectClip = false,
    Duration? videoPosition,
    Duration? videoDuration,
    List<VideoClip>? liveClips,
    bool clearLiveClips = false,
    List<AudioClip>? audioClips,
  }) {
    return EditorLoaded(
      projectId: projectId ?? this.projectId,
      timelineHistory: timelineHistory ?? this.timelineHistory,
      historyIndex: historyIndex ?? this.historyIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      videoPosition: videoPosition ?? this.videoPosition,
      videoDuration: videoDuration ?? this.videoDuration,
      selectedClipIndex: deselectClip
          ? null
          : (selectedClipIndex ?? this.selectedClipIndex),
      liveClips: clearLiveClips ? null : liveClips ?? this.liveClips,
      audioClips: audioClips ?? this.audioClips,
    );
  }

  @override
  List<Object?> get props => [
    projectId,
    timelineHistory,
    historyIndex,
    isPlaying,
    selectedClipIndex,
    videoDuration,
    videoPosition,
    liveClips,
    audioClips,
  ];
}

class EditorProcessing extends EditorLoaded {
  final double progress;
  final ProcessingType type;

  const EditorProcessing({
    required super.projectId,
    required super.timelineHistory,
    required super.historyIndex,
    required super.isPlaying,
    super.selectedClipIndex,
    super.videoPosition,
    super.videoDuration,
    super.liveClips,
    super.audioClips,
    required this.progress,
    required this.type,
  });

  @override
  List<Object?> get props => [
    projectId,
    timelineHistory,
    historyIndex,
    isPlaying,
    selectedClipIndex,
    videoDuration,
    videoPosition,
    liveClips,
    audioClips,
    progress,
    type,
  ];
}
