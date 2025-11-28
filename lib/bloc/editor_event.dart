// lib/bloc/editor_event.dart
part of 'editor_bloc.dart';

abstract class EditorEvent extends Equatable {
  const EditorEvent();
  @override
  List<Object?> get props => [];
}

// --- Project Events ---
class EditorProjectLoaded extends EditorEvent {
  final Project project;
  const EditorProjectLoaded(this.project);
}

class EditorProjectSaved extends EditorEvent {}

// --- Playback Events ---
class PlaybackStatusChanged extends EditorEvent {
  final bool isPlaying;
  const PlaybackStatusChanged(this.isPlaying);
}

class VideoPositionChanged extends EditorEvent {
  final Duration position;
  const VideoPositionChanged(this.position);
}

class VideoSeekRequsted extends EditorEvent {
  final Duration position;
  const VideoSeekRequsted(this.position);
}

// --- Selection Events ---
class ClipTapped extends EditorEvent {
  final String? trackId;
  final String? clipId;
  const ClipTapped({this.trackId, this.clipId});
}

class ClipSplitRequested extends EditorEvent {
  final Duration splitAt;
  const ClipSplitRequested({required this.splitAt});
}

class ClipDeleted extends EditorEvent {
  final String trackId;
  final String clipId;
  const ClipDeleted({required this.trackId, required this.clipId});
}

class ClipAdded extends EditorEvent {
  final File videoFile;
  const ClipAdded(this.videoFile);
}

// --- Trim Events ---
class ClipTrimRequested extends EditorEvent {
  final String trackId;
  final String clipId;
  final Duration delta;
  final bool isStartHandle;

  const ClipTrimRequested({
    required this.trackId,
    required this.clipId,
    required this.delta,
    required this.isStartHandle,
  });

  @override
  List<Object?> get props => [trackId, clipId, delta, isStartHandle];
}

class ClipRippleRequested extends EditorEvent {
  final String trackId;
  const ClipRippleRequested(this.trackId);
}

class ClipMoved extends EditorEvent {
  final String trackId;
  final String clipId;
  final Duration delta;

  const ClipMoved({
    required this.trackId,
    required this.clipId,
    required this.delta,
  });

  @override
  List<Object?> get props => [trackId, clipId, delta];
}

class ClipTextUpdated extends EditorEvent {
  final String trackId;
  final String clipId;
  final String text;
  final TextStyleModel style;

  const ClipTextUpdated({
    required this.trackId,
    required this.clipId,
    required this.text,
    required this.style,
  });
}

class TrackLocked extends EditorEvent {
  final String trackId;
  const TrackLocked(this.trackId);
}

class TrackMuted extends EditorEvent {
  final String trackId;
  const TrackMuted(this.trackId);
}

class TrackVisibilityToggled extends EditorEvent {
  final String trackId;
  const TrackVisibilityToggled(this.trackId);
}

class UpdateExportProgress extends EditorEvent {
  final double progress;
  const UpdateExportProgress(this.progress);
  @override
  List<Object> get props => [progress];
}

class ExportStarted extends EditorEvent {
  final ExportSettings settings;
  const ExportStarted(this.settings);
}

class AudioTrackAdded extends EditorEvent {
  final File audioFile;
  const AudioTrackAdded(this.audioFile);
}

class TextTrackAdded extends EditorEvent {
  final String text;
  final TextStyleModel style;
  const TextTrackAdded(this.text, this.style);
}

class OverlayTrackAdded extends EditorEvent {
  final File videoFile;
  const OverlayTrackAdded(this.videoFile);
}

class ClipTransformUpdated extends EditorEvent {
  final String trackId;
  final String clipId;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotation;

  const ClipTransformUpdated({
    required this.trackId,
    required this.clipId,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.rotation,
  });

  @override
  List<Object?> get props => [
    trackId,
    clipId,
    offsetX,
    offsetY,
    scale,
    rotation,
  ];
}

class ClipVolumeChanged extends EditorEvent {
  final double volume; // 0.0 to 2.0
  const ClipVolumeChanged(this.volume);
}

class ClipSpeedChanged extends EditorEvent {
  final double speed; // 0.1x to 10.0x
  const ClipSpeedChanged(this.speed);
}

class ProjectCanvasRatioChanged extends EditorEvent {
  final double? ratio; // null means "Fit" / "Original"
  const ProjectCanvasRatioChanged(this.ratio);
}

class UndoRequested extends EditorEvent {}

class RedoRequested extends EditorEvent {}

class ClipTransitionChanged extends EditorEvent {
  final String trackId;
  final String clipId; // The ID of the clip *starting* the transition (Clip B)
  final String? transitionType; // null = remove
  final Duration duration;

  const ClipTransitionChanged({
    required this.trackId,
    required this.clipId,
    required this.transitionType,
    this.duration = const Duration(milliseconds: 500),
  });
}
