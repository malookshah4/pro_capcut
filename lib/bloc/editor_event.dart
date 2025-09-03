part of 'editor_bloc.dart';

abstract class EditorEvent extends Equatable {
  const EditorEvent();

  @override
  List<Object> get props => [];
}

// Sent when the screen first loads with the initial video
class EditorVideoInitialized extends EditorEvent {
  final File videoFile;
  const EditorVideoInitialized(this.videoFile);
}

// Sent when the user presses the Stabilize button
class StabilizationStarted extends EditorEvent {}

// Sent when the user presses Undo/Redo
class UndoRequested extends EditorEvent {}

class RedoRequested extends EditorEvent {}

// Sent by the player when play/pause state changes
class PlaybackStatusChanged extends EditorEvent {
  final bool isPlaying;
  const PlaybackStatusChanged(this.isPlaying);
}

class NoiseReductionApplied extends EditorEvent {}

class AiEnhanceVoiceStarted extends EditorEvent {}

class ClipTapped extends EditorEvent {
  // We pass the index of the clip that was tapped. Null means deselect.
  final int? clipIndex;
  const ClipTapped(this.clipIndex);

  @override
  List<Object> get props => [if (clipIndex != null) clipIndex!];
}

class VideoPositionChanged extends EditorEvent {
  final Duration position;
  final Duration duration;
  const VideoPositionChanged(this.position, this.duration);
}

class VideoSeekRequsted extends EditorEvent {
  final Duration position;
  const VideoSeekRequsted(this.position);
}

class ClipSplitRequested extends EditorEvent {
  final int clipIndex;
  final Duration splitAt; // The global timeline position to split at
  const ClipSplitRequested({required this.clipIndex, required this.splitAt});

  @override
  List<Object> get props => [clipIndex, splitAt];
}

class ClipDeleted extends EditorEvent {}

class ExportStarted extends EditorEvent {}

class ClipSpeedChanged extends EditorEvent {
  final double newSpeed;
  const ClipSpeedChanged(this.newSpeed);

  @override
  List<Object> get props => [newSpeed];
}
