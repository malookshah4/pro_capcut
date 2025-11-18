// lib/bloc/editor_bloc.dart
import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/utils/thumbnail_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/text_style_model.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(EditorInitial()) {
    on<EditorProjectLoaded>(_onProjectLoaded);
    on<EditorProjectSaved>(_onProjectSaved);
    on<PlaybackStatusChanged>(_onPlaybackStatusChanged);
    on<VideoPositionChanged>(_onVideoPositionChanged);
    on<VideoSeekRequsted>(_onVideoSeekRequested);
    on<ClipTapped>(_onClipTapped);
    on<ClipAdded>(_onClipAdded);
    on<ClipSplitRequested>(_onClipSplitRequested);
    on<ClipDeleted>(_onClipDeleted);
    on<ClipTrimRequested>(_onClipTrimRequested);
    on<ClipRippleRequested>(_onClipRippleRequested);
    on<ClipTextUpdated>(_onClipTextUpdated);
    on<AudioTrackAdded>(_onAudioTrackAdded);
    on<TextTrackAdded>(_onTextTrackAdded);
    on<OverlayTrackAdded>(_onOverlayTrackAdded);
    on<ClipTransformUpdated>(_onClipTransformUpdated);
    on<ClipMoved>(_onClipMoved); // NEW
  }

  void _onProjectLoaded(EditorProjectLoaded event, Emitter<EditorState> emit) {
    emit(EditorLoaded(project: event.project));
  }

  void _onPlaybackStatusChanged(
    PlaybackStatusChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    emit((state as EditorLoaded).copyWith(isPlaying: event.isPlaying));
  }

  void _onVideoPositionChanged(
    VideoPositionChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    emit((state as EditorLoaded).copyWith(videoPosition: event.position));
  }

  void _onVideoSeekRequested(
    VideoSeekRequsted event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    emit((state as EditorLoaded).copyWith(videoPosition: event.position));
  }

  void _onClipTapped(ClipTapped event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipId == event.clipId && event.clipId != null) {
      emit(
        currentState.copyWith(
          clearSelectedTrackId: true,
          clearSelectedClipId: true,
        ),
      );
    } else {
      emit(
        currentState.copyWith(
          selectedTrackId: event.trackId,
          selectedClipId: event.clipId,
        ),
      );
    }
  }

  Future<void> _onClipTextUpdated(
    ClipTextUpdated event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );

    if (clipIndex == -1) return;

    final oldClip = track.clips[clipIndex] as TextClip;
    final newClip = TextClip(
      id: oldClip.id,
      startTimeInTimelineInMicroseconds:
          oldClip.startTimeInTimelineInMicroseconds,
      durationInMicroseconds: oldClip.durationInMicroseconds,
      text: event.text,
      style: event.style,
    );

    track.clips[clipIndex] = newClip;
    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  // --- NEW: Handle Clip Moving (Drag body) ---
  Future<void> _onClipMoved(ClipMoved event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );

    // We generally don't allow moving clips on the Main Video Track manually
    // because it is magnetic (Auto-Ripple). Only Overlay/Audio/Text.
    if (track.type == TrackType.video) return;

    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final deltaMicro = event.delta.inMicroseconds;

    // New Start Time
    int newStartTime = clip.startTimeInTimelineInMicroseconds + deltaMicro;
    if (newStartTime < 0) newStartTime = 0; // Cannot go before 0:00

    TimelineClip? updatedClip;

    if (clip is AudioClip) {
      updatedClip = clip.copyWith(
        startTimeInTimelineInMicroseconds: newStartTime,
      );
    } else if (clip is TextClip) {
      updatedClip = clip.copyWith(
        startTimeInTimelineInMicroseconds: newStartTime,
      );
    } else if (clip is VideoClip) {
      updatedClip = clip.copyWith(
        startTimeInTimelineInMicroseconds: newStartTime,
      );
    }

    if (updatedClip != null) {
      track.clips[clipIndex] = updatedClip;
      // Instant update, no save
      emit(
        currentState.copyWith(
          project: currentState.project,
          version: currentState.version + 1,
        ),
      );
    }
  }

  Future<void> _onClipAdded(ClipAdded event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    emit(currentState.copyWith(processingType: ProcessingType.export));
    try {
      final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());
      final videoTrack = currentState.videoTrack;
      final startTime = currentState.videoDuration;
      final newClip = VideoClip(
        id: const Uuid().v4(),
        sourcePath: event.videoFile.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        startTimeInTimelineInMicroseconds: startTime.inMicroseconds,
        durationInMicroseconds: totalDuration.inMicroseconds,
      );
      videoTrack.clips.add(newClip);
      await currentState.project.save();
      emit(
        currentState.copyWith(
          project: currentState.project,
          clearProcessing: true,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(clearProcessing: true));
    }
  }

  // --- UNIVERSAL SPLIT HANDLER ---
  Future<void> _onClipSplitRequested(
    ClipSplitRequested event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    EditorTrack? trackToSplit;
    TimelineClip? clipToSplit;

    // Find clip under playhead
    for (var track in currentState.project.tracks) {
      for (var clip in track.clips) {
        if (event.splitAt > clip.startTime && event.splitAt < clip.endTime) {
          trackToSplit = track;
          clipToSplit = clip;
          break;
        }
      }
      if (trackToSplit != null) break;
    }

    if (trackToSplit == null || clipToSplit == null) return;

    // --- 1. Video Split Logic ---
    if (clipToSplit is VideoClip) {
      final originalClip = clipToSplit;
      final splitPointInTimeline = event.splitAt;
      final clip1Duration = splitPointInTimeline - originalClip.startTime;
      final clip2Duration = originalClip.endTime - splitPointInTimeline;

      final percentSplit =
          clip1Duration.inMicroseconds / originalClip.duration.inMicroseconds;
      final sourceSplitPoint =
          (originalClip.endTimeInSource.inMicroseconds -
                  originalClip.startTimeInSource.inMicroseconds) *
              percentSplit +
          originalClip.startTimeInSource.inMicroseconds;

      final clip1 = originalClip.copyWith(
        endTimeInSourceInMicroseconds: sourceSplitPoint.round(),
        durationInMicroseconds: clip1Duration.inMicroseconds,
      );

      final clip2 = VideoClip(
        id: const Uuid().v4(),
        sourcePath: originalClip.sourcePath,
        sourceDurationInMicroseconds: originalClip.sourceDurationInMicroseconds,
        startTimeInSourceInMicroseconds: sourceSplitPoint.round(),
        endTimeInSourceInMicroseconds:
            originalClip.endTimeInSourceInMicroseconds,
        startTimeInTimelineInMicroseconds: splitPointInTimeline.inMicroseconds,
        durationInMicroseconds: clip2Duration.inMicroseconds,
        speed: originalClip.speed,
        volume: originalClip.volume,
      );

      final clipIndex = trackToSplit.clips.indexOf(originalClip);
      trackToSplit.clips[clipIndex] = clip1;
      trackToSplit.clips.insert(clipIndex + 1, clip2);
    }
    // --- 2. Text Split Logic ---
    else if (clipToSplit is TextClip) {
      final originalClip = clipToSplit;
      final splitPointInTimeline = event.splitAt;
      final clip1Duration = splitPointInTimeline - originalClip.startTime;
      final clip2Duration = originalClip.endTime - splitPointInTimeline;

      final clip1 = originalClip.copyWith(
        durationInMicroseconds: clip1Duration.inMicroseconds,
      );

      final clip2 = originalClip.copyWith(
        id: const Uuid().v4(),
        startTimeInTimelineInMicroseconds: splitPointInTimeline.inMicroseconds,
        durationInMicroseconds: clip2Duration.inMicroseconds,
      );

      final clipIndex = trackToSplit.clips.indexOf(originalClip);
      trackToSplit.clips[clipIndex] = clip1;
      trackToSplit.clips.insert(clipIndex + 1, clip2);
    }
    // --- 3. Audio Split Logic ---
    else if (clipToSplit is AudioClip) {
      final originalClip = clipToSplit;
      final splitPointInTimeline = event.splitAt;

      final clip1Duration = splitPointInTimeline - originalClip.startTime;
      final clip2Duration = originalClip.endTime - splitPointInTimeline;

      // Calculate offset in source file for the 2nd clip
      final splitOffsetInSource =
          originalClip.startTimeInSourceInMicroseconds +
          clip1Duration.inMicroseconds;

      final clip1 = originalClip.copyWith(
        durationInMicroseconds: clip1Duration.inMicroseconds,
      );

      final clip2 = AudioClip(
        id: const Uuid().v4(),
        filePath: originalClip.filePath,
        volume: originalClip.volume,
        startTimeInTimelineInMicroseconds: splitPointInTimeline.inMicroseconds,
        durationInMicroseconds: clip2Duration.inMicroseconds,
        startTimeInSourceInMicroseconds: splitOffsetInSource,
      );

      final clipIndex = trackToSplit.clips.indexOf(originalClip);
      trackToSplit.clips[clipIndex] = clip1;
      trackToSplit.clips.insert(clipIndex + 1, clip2);
    }

    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        clearSelectedClipId: true,
        clearSelectedTrackId: true,
      ),
    );
  }

  Future<void> _onClipDeleted(
    ClipDeleted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final project = currentState.project;

    // 1. Find the Track
    final trackIndex = project.tracks.indexWhere((t) => t.id == event.trackId);
    if (trackIndex == -1) return; // Track not found
    final track = project.tracks[trackIndex];

    // 2. Find the Clip
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );
    if (clipIndex == -1) return; // Clip not found

    final clipToRemove = track.clips[clipIndex] as TimelineClip;
    final durationToRemove = clipToRemove.duration;

    // 3. Remove the Clip
    track.clips.removeAt(clipIndex);

    // 4. Handle Ripple Logic
    if (track.type == TrackType.video) {
      // --- MAIN TRACK: Horizontal Ripple ---
      // Shift all subsequent clips to the left
      for (int i = clipIndex; i < track.clips.length; i++) {
        final clip = track.clips[i] as TimelineClip;
        if (clip is VideoClip) {
          track.clips[i] = clip.copyWith(
            startTimeInTimelineInMicroseconds:
                clip.startTimeInTimelineInMicroseconds -
                durationToRemove.inMicroseconds,
          );
        }
      }
    } else {
      // --- OVERLAY TRACKS: Vertical Ripple (Auto-Collapse) ---
      // If the track is now empty, remove the track entirely from the project.
      if (track.clips.isEmpty) {
        project.tracks.removeAt(trackIndex);
      }
    }

    // 5. Save and Update UI
    await project.save();
    emit(
      currentState.copyWith(
        project: project,
        clearSelectedClipId: true,
        clearSelectedTrackId: true,
        version: currentState.version + 1, // Force Rebuild
      ),
    );
  }

  Future<void> _onClipTrimRequested(
    ClipTrimRequested event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );

    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final deltaMicro = event.delta.inMicroseconds;

    // --- LOGIC A: Video Clip (Constrained by Source File) ---
    if (clip is VideoClip) {
      VideoClip updatedClip = clip;
      if (event.isStartHandle) {
        final newStartTimeInSource =
            clip.startTimeInSourceInMicroseconds + deltaMicro;
        final maxDelta =
            clip.durationInMicroseconds - 500000; // Min 0.5s duration
        if (newStartTimeInSource < 0 || deltaMicro > maxDelta) return;

        updatedClip = clip.copyWith(
          startTimeInSourceInMicroseconds: newStartTimeInSource,
          startTimeInTimelineInMicroseconds:
              clip.startTimeInTimelineInMicroseconds + deltaMicro,
          durationInMicroseconds: clip.durationInMicroseconds - deltaMicro,
        );
      } else {
        final newEndTimeInSource =
            clip.endTimeInSourceInMicroseconds + deltaMicro;
        if (newEndTimeInSource > clip.sourceDurationInMicroseconds) return;
        final minDuration = 500000;
        if ((clip.durationInMicroseconds + deltaMicro) < minDuration) return;

        updatedClip = clip.copyWith(
          endTimeInSourceInMicroseconds: newEndTimeInSource,
          durationInMicroseconds: clip.durationInMicroseconds + deltaMicro,
        );
      }
      track.clips[clipIndex] = updatedClip;
    }
    // --- LOGIC B: Text Clip (Infinite Source) ---
    else if (clip is TextClip) {
      TextClip updatedClip = clip;
      final minDuration = 500000; // 0.5s

      if (event.isStartHandle) {
        // START HANDLE:
        // 1. Start Time moves by delta (dragging right = +delta, left = -delta)
        // 2. Duration shrinks by delta (dragging right = shorter)

        final newDuration = clip.durationInMicroseconds - deltaMicro;

        // Prevent duration < 0.5s or startTime < 0
        if (newDuration < minDuration) return;
        final newStartTime =
            clip.startTimeInTimelineInMicroseconds + deltaMicro;
        if (newStartTime < 0) return;

        updatedClip = clip.copyWith(
          startTimeInTimelineInMicroseconds: newStartTime,
          durationInMicroseconds: newDuration,
        );
      } else {
        // END HANDLE:
        // 1. Duration grows by delta
        // 2. Start Time stays same

        final newDuration = clip.durationInMicroseconds + deltaMicro;
        if (newDuration < minDuration) return;

        updatedClip = clip.copyWith(durationInMicroseconds: newDuration);
      }
      track.clips[clipIndex] = updatedClip;
    }

    // Emit state with version bump for 60fps update (No Save yet)
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onClipRippleRequested(
    ClipRippleRequested event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );
    if (track.type == TrackType.video) {
      int currentTimelinePos = 0;
      for (int i = 0; i < track.clips.length; i++) {
        final clip = track.clips[i] as VideoClip;
        if (clip.startTimeInTimelineInMicroseconds != currentTimelinePos) {
          track.clips[i] = clip.copyWith(
            startTimeInTimelineInMicroseconds: currentTimelinePos,
          );
        }
        currentTimelinePos += track.clips[i].durationInMicroseconds as int;
      }
      await currentState.project.save();
      emit(
        currentState.copyWith(
          project: currentState.project,
          version: currentState.version + 1,
        ),
      );
    } else {
      await currentState.project.save();
    }
  }

  Future<void> _onProjectSaved(
    EditorProjectSaved event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final project = currentState.project;
    final videoTrack = currentState.videoTrack;
    if (videoTrack.clips.isNotEmpty) {
      final firstClip = videoTrack.clips.first as VideoClip;
      if (project.thumbnailPath == null) {
        await ThumbnailUtils.deleteThumbnail(project.thumbnailPath);
        project.thumbnailPath = await ThumbnailUtils.generateAndSaveThumbnail(
          firstClip.sourcePath,
          project.id,
        );
      }
    }
    project.lastModified = DateTime.now();
    await project.save();
    emit(currentState.copyWith(project: project));
  }

  Future<void> _onAudioTrackAdded(
    AudioTrackAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    emit(currentState.copyWith(processingType: ProcessingType.export));
    try {
      final info = await FFprobeKit.getMediaInformation(event.audioFile.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());

      final newClip = AudioClip(
        id: const Uuid().v4(),
        filePath: event.audioFile.path,
        startTimeInTimelineInMicroseconds:
            currentState.videoPosition.inMicroseconds,
        durationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0, // Start from beginning of file
      );

      final newTrack = EditorTrack(
        id: const Uuid().v4(),
        type: TrackType.audio,
        clips: [newClip],
      );
      currentState.project.tracks.add(newTrack);
      await currentState.project.save();
      emit(
        currentState.copyWith(
          project: currentState.project,
          clearProcessing: true,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(clearProcessing: true));
    }
  }

  Future<void> _onTextTrackAdded(
    TextTrackAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final newClip = TextClip(
      id: const Uuid().v4(),
      text: event.text,
      style: event.style,
      startTimeInTimelineInMicroseconds:
          currentState.videoPosition.inMicroseconds,
      durationInMicroseconds: const Duration(seconds: 3).inMicroseconds,
    );
    final newTrack = EditorTrack(
      id: const Uuid().v4(),
      type: TrackType.text,
      clips: [newClip],
    );
    currentState.project.tracks.add(newTrack);
    await currentState.project.save();
    emit(currentState.copyWith(project: currentState.project));
  }

  Future<void> _onOverlayTrackAdded(
    OverlayTrackAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    emit(currentState.copyWith(processingType: ProcessingType.export));
    try {
      final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());
      final newClip = VideoClip(
        id: const Uuid().v4(),
        sourcePath: event.videoFile.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        startTimeInTimelineInMicroseconds:
            currentState.videoPosition.inMicroseconds,
        durationInMicroseconds: totalDuration.inMicroseconds,
      );
      final newTrack = EditorTrack(
        id: const Uuid().v4(),
        type: TrackType.overlay,
        clips: [newClip],
      );
      currentState.project.tracks.add(newTrack);
      await currentState.project.save();
      emit(
        currentState.copyWith(
          project: currentState.project,
          clearProcessing: true,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(clearProcessing: true));
    }
  }

  Future<void> _onClipTransformUpdated(
    ClipTransformUpdated event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );

    if (clipIndex == -1) return;

    // Only supports TextClip for now (can extend to Overlay Video later)
    if (track.clips[clipIndex] is TextClip) {
      final oldClip = track.clips[clipIndex] as TextClip;

      // Create new clip with updated transform values
      final newClip = TextClip(
        id: oldClip.id,
        startTimeInTimelineInMicroseconds:
            oldClip.startTimeInTimelineInMicroseconds,
        durationInMicroseconds: oldClip.durationInMicroseconds,
        text: oldClip.text,
        style: oldClip.style,
        // Update these 4 fields:
        offsetX: event.offsetX,
        offsetY: event.offsetY,
        scale: event.scale,
        rotation: event.rotation,
      );

      track.clips[clipIndex] = newClip;

      // Update UI instantly (no save)
      emit(
        currentState.copyWith(
          project: currentState.project,
          version: currentState.version + 1,
        ),
      );
    }
  }
}
