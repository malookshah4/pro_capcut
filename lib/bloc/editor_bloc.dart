// lib/bloc/editor_bloc.dart
import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gal/gal.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/utils/TextToImageService.dart';
import 'package:pro_capcut/utils/ffmpeg_command_builder.dart';
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

    // Actions that change project state (Wrapped with History)
    on<ClipAdded>(_onClipAdded);
    on<ClipSplitRequested>(_onClipSplitRequested);
    on<ClipDeleted>(_onClipDeleted);
    on<ClipTrimRequested>(_onClipTrimRequested);
    on<ClipMoved>(_onClipMoved);
    on<ClipRippleRequested>(_onClipRippleRequested);
    on<ClipTextUpdated>(_onClipTextUpdated);
    on<ClipTransformUpdated>(_onClipTransformUpdated);
    on<AudioTrackAdded>(_onAudioTrackAdded);
    on<TextTrackAdded>(_onTextTrackAdded);
    on<OverlayTrackAdded>(_onOverlayTrackAdded);
    on<ClipVolumeChanged>(_onClipVolumeChanged);
    on<ClipSpeedChanged>(_onClipSpeedChanged);
    on<ProjectCanvasRatioChanged>(_onProjectCanvasRatioChanged);
    on<ClipTransitionChanged>(_onClipTransitionChanged);

    // Undo/Redo
    on<UndoRequested>(_onUndoRequested);
    on<RedoRequested>(_onRedoRequested);

    on<ExportStarted>(_onExportStarted);
    on<UpdateExportProgress>((event, emit) {
      if (state is EditorLoaded) {
        emit(
          (state as EditorLoaded).copyWith(
            processingProgress: event.progress,
            processingType: ProcessingType.export,
          ),
        );
      }
    });
  }

  // Call this BEFORE making changes to state.project
  void _saveToHistory(Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    // 1. Create a deep copy of the current project
    // We simulate deep copy by serializing/deserializing or manual copy
    // Since our copyWith methods are shallow, we must rely on Project.copyWith
    // ensuring it creates new Lists for tracks.

    // NOTE: You must ensure Project.copyWith creates NEW List instances,
    // otherwise modifying the new list modifies the old one.
    // We will trust the models are immutable enough or we clone the lists here.

    // Simple Clone Strategy for Lists in Project:
    final deepClonedTracks = currentState.project.tracks.map((t) {
      // Clone track
      return EditorTrack(
        id: t.id,
        type: t.type,
        // Clone clips list
        clips: List.from(t.clips),
        locked: t.locked,
        muted: t.muted,
        visible: t.visible,
      );
    }).toList();

    final projectSnapshot = currentState.project.copyWith(
      tracks: deepClonedTracks,
    );

    final newUndoStack = List<Project>.from(currentState.undoStack)
      ..add(projectSnapshot);

    // Limit stack size (e.g. 20 steps)
    if (newUndoStack.length > 20) {
      newUndoStack.removeAt(0);
    }

    emit(
      currentState.copyWith(
        undoStack: newUndoStack,
        redoStack: [], // Clear redo stack on new action
      ),
    );
  }

  void _onUndoRequested(UndoRequested event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.undoStack.isEmpty) return;

    final previousProject = currentState.undoStack.last;
    final newUndoStack = List<Project>.from(currentState.undoStack)
      ..removeLast();

    // Push CURRENT state to Redo Stack before restoring old one
    final deepClonedCurrentTracks = currentState.project.tracks.map((t) {
      return EditorTrack(
        id: t.id,
        type: t.type,
        clips: List.from(t.clips),
        locked: t.locked,
        muted: t.muted,
        visible: t.visible,
      );
    }).toList();
    final currentSnapshot = currentState.project.copyWith(
      tracks: deepClonedCurrentTracks,
    );

    final newRedoStack = List<Project>.from(currentState.redoStack)
      ..add(currentSnapshot);

    // Restore
    emit(
      currentState.copyWith(
        project: previousProject,
        undoStack: newUndoStack,
        redoStack: newRedoStack,
        version: currentState.version + 1,
      ),
    );

    // Sync to DB
    final box = Hive.box<Project>('projects');
    await box.put(previousProject.id, previousProject);
  }

  void _onRedoRequested(RedoRequested event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.redoStack.isEmpty) return;

    final nextProject = currentState.redoStack.last;
    final newRedoStack = List<Project>.from(currentState.redoStack)
      ..removeLast();

    // Push CURRENT state to Undo Stack
    final deepClonedCurrentTracks = currentState.project.tracks.map((t) {
      return EditorTrack(
        id: t.id,
        type: t.type,
        clips: List.from(t.clips),
        locked: t.locked,
        muted: t.muted,
        visible: t.visible,
      );
    }).toList();
    final currentSnapshot = currentState.project.copyWith(
      tracks: deepClonedCurrentTracks,
    );

    final newUndoStack = List<Project>.from(currentState.undoStack)
      ..add(currentSnapshot);

    // Restore
    emit(
      currentState.copyWith(
        project: nextProject,
        undoStack: newUndoStack,
        redoStack: newRedoStack,
        version: currentState.version + 1,
      ),
    );

    // Sync to DB
    final box = Hive.box<Project>('projects');
    await box.put(nextProject.id, nextProject);
  }

  Future<void> _onClipTransitionChanged(
    ClipTransitionChanged event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit); // Undo support

    final currentState = state as EditorLoaded;
    final trackIndex = currentState.project.tracks.indexWhere(
      (t) => t.id == event.trackId,
    );
    if (trackIndex == -1) return;

    final track = currentState.project.tracks[trackIndex];
    final clipIndex = track.clips.indexWhere((c) => c.id == event.clipId);
    if (clipIndex == -1) return;

    // 1. Update the specific clip
    final clip = track.clips[clipIndex] as VideoClip;
    final updatedClip = clip.copyWith(
      transitionType: event.transitionType,
      transitionDurationMicroseconds: event.duration.inMicroseconds,
    );
    track.clips[clipIndex] = updatedClip;

    // 2. RIPPLE LOGIC: Recalculate timeline positions
    // Transitions CAUSE OVERLAP.
    // If Clip B has a 1s transition, it must start 1s BEFORE Clip A ends.
    if (track.type == TrackType.video) {
      int currentTimelinePos = 0;
      for (int i = 0; i < track.clips.length; i++) {
        final c = track.clips[i] as VideoClip;

        // If this clip has a transition (and isn't the first one), move it BACK by duration
        int offset = 0;
        if (i > 0 && c.transitionType != null) {
          offset = c.transitionDurationMicroseconds;
        }

        // The start time is CurrentPos - Offset
        // Ensure we don't go below 0
        int newStart = currentTimelinePos - offset;
        if (newStart < 0) newStart = 0;

        if (c.startTimeInTimelineInMicroseconds != newStart) {
          track.clips[i] = c.copyWith(
            startTimeInTimelineInMicroseconds: newStart,
          );
        }

        // Advance CurrentPos by the clip's visual duration
        // Visual Duration = Full Duration.
        // (The overlap logic is handled by the *start* time of the *next* clip)
        currentTimelinePos = newStart + c.durationInMicroseconds;
      }
    }

    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onExportStarted(
    ExportStarted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    // 1. Permissions
    await [Permission.storage, Permission.photos, Permission.videos].request();

    // 2. CRITICAL: Stop ALL video players and wait for disposal
    emit(
      currentState.copyWith(
        processingType: ProcessingType.export,
        processingProgress: 0.0,
        isExporting: true,
        isPlaying: false,
      ),
    );

    // 3. WAIT FOR PLAYER DISPOSAL (Gives AudioTrack time to release lock)
    await Future.delayed(const Duration(seconds: 3));

    try {
      final builder = FFmpegCommandBuilder();
      final textGenerator = TextToImageService();

      // DEFINE CANVAS RESOLUTION
      // This must match the resolution used in FFmpegCommandBuilder (1080x1920)
      const double canvasWidth = 1080.0;
      const double canvasHeight = 1920.0;

      // --- A. Main Video ---
      final videoTrack = currentState.videoTrack;
      final mainClips = videoTrack.clips.cast<VideoClip>();
      final Map<String, bool> hasAudioMap = {};

      for (var c in mainClips) {
        hasAudioMap[c.sourcePath] = true;
      }

      print("Main clips count: ${mainClips.length}");
      builder.setMainVideo(mainClips, hasAudioMap);

      // --- B. Overlays + Text (With Coordinate Conversion) ---
      final List<VideoClip> allVisualOverlays = [];

      for (final track in currentState.project.tracks) {
        // 1. Handle Video Overlays
        if (track.type == TrackType.overlay) {
          for (final clip in track.clips) {
            if (clip is VideoClip) {
              // Convert normalized offset (0.0-1.0) to Pixels relative to center
              // Formula: (Value - 0.5) * Dimension
              // If offsetX is 0.5 (Center), result is 0 pixels.
              final double pixelX = ((clip.offsetX ?? 0.5) - 0.5) * canvasWidth;
              final double pixelY =
                  ((clip.offsetY ?? 0.5) - 0.5) * canvasHeight;

              allVisualOverlays.add(
                clip.copyWith(
                  offsetX: pixelX, // Requires 'x' field in VideoClip model
                  offsetY: pixelY, // Requires 'y' field in VideoClip model
                ),
              );
            }
          }
        }
        // 2. Handle Text (Convert to Image -> Add as Overlay)
        else if (track.type == TrackType.text) {
          for (final clip in track.clips) {
            if (clip is TextClip) {
              // Generate PNG
              String? imagePath = await textGenerator.generateImageFromText(
                clip,
              );

              if (imagePath != null && File(imagePath).existsSync()) {
                // Calculate Pixels from Center for Text
                final double pixelX =
                    ((clip.offsetX ?? 0.5) - 0.5) * canvasWidth;
                final double pixelY =
                    ((clip.offsetY ?? 0.5) - 0.5) * canvasHeight;

                allVisualOverlays.add(
                  VideoClip(
                    id: clip.id,
                    sourcePath: imagePath,
                    startTimeInTimelineInMicroseconds:
                        clip.startTimeInTimelineInMicroseconds,
                    durationInMicroseconds: clip.durationInMicroseconds,
                    startTimeInSourceInMicroseconds: 0,
                    endTimeInSourceInMicroseconds: clip.durationInMicroseconds,
                    sourceDurationInMicroseconds: clip.durationInMicroseconds,

                    // Transform Properties
                    scale: clip.scale ?? 1.0,
                    rotation: clip.rotation ?? 0.0,

                    // CRITICAL: Pass the Pixel Coordinates calculated above
                    offsetX: pixelX,
                    offsetY: pixelY,

                    // Default/Ignored properties for images
                    speed: 1.0,
                    volume: 0.0,
                  ),
                );
              }
            }
          }
        }
      }

      print("Overlays count (Video + Text): ${allVisualOverlays.length}");
      builder.addOverlays(allVisualOverlays);

      // --- C. Audio ---
      final audioClips = currentState.project.tracks
          .where((t) => t.type == TrackType.audio)
          .expand((t) => t.clips)
          .cast<AudioClip>()
          .toList();

      print("Audio clips count: ${audioClips.length}");
      builder.addAudioTracks(audioClips);

      // --- D. Execution ---
      final dir = Directory("/storage/emulated/0/Movies");
      final outputPath =
          "${dir.path}/final_export_${DateTime.now().millisecondsSinceEpoch}.mp4";

      final file = File(outputPath);
      if (file.existsSync()) file.deleteSync();

      final command = builder.build(outputPath, event.settings);
      print("FFmpeg Command Length: ${command.length}");

      // --- DEFINING THE MISSING VARIABLES HERE ---
      final totalDurationMs = currentState.videoDuration.inMilliseconds;
      int lastPercent = 0;
      bool isComplete = false;

      // Cancel any existing sessions
      await FFmpegKit.cancel();
      final sessionCompleter = Completer<void>();

      // Progress Callback
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        if (isComplete) return;

        final time = stats.getTime();
        if (time > 0 && totalDurationMs > 0) {
          double progress = (time / totalDurationMs).clamp(0.0, 0.95);
          final int percent = (progress * 100).toInt();

          if (percent > lastPercent) {
            lastPercent = percent;
            // Note: 'isClosed' is a property of the Bloc class
            if (!isClosed) {
              add(UpdateExportProgress(progress));
            }
          }
        }
      });

      print("Starting FFmpeg execution...");

      // Execute Async
      await FFmpegKit.executeAsync(command, (session) async {
        try {
          final returnCode = await session.getReturnCode();
          isComplete = true; // Variable is now accessible

          if (!isClosed) add(const UpdateExportProgress(1.0));

          await Future.delayed(const Duration(milliseconds: 500));

          if (ReturnCode.isSuccess(returnCode)) {
            print("FFmpeg process completed successfully");
            // Save to Gallery
            final outputFile = File(outputPath);
            if (await outputFile.exists()) {
              await Gal.putVideo(outputPath);
              print("Video successfully saved to gallery" + outputPath);
              Fluttertoast.showToast(msg: "Video saved to Gallery! 📸");
            }
          } else {
            print("Export Failed with return code: ${returnCode?.getValue()}");
            final logs = await session.getAllLogs();
            for (final log in logs) {
              print("FFmpeg Log: ${log.getMessage()}");
            }
            Fluttertoast.showToast(msg: "Export Failed - Check logs");
          }
        } catch (e) {
          print("Error in export session: $e");
          Fluttertoast.showToast(msg: "Export Error: $e");
        } finally {
          sessionCompleter.complete();
        }
      });

      // Wait for completion
      await sessionCompleter.future;

      // Reset state
      await Future.delayed(const Duration(milliseconds: 500));
      emit(
        currentState.copyWith(
          processingType: ProcessingType.none,
          processingProgress: 0.0,
          isExporting: false,
        ),
      );
    } catch (e, s) {
      print("Export Error: $e\n$s");
      emit(
        currentState.copyWith(
          processingType: ProcessingType.none,
          processingProgress: 0.0,
          isExporting: false,
        ),
      );
      Fluttertoast.showToast(msg: "Export Error: ${e.toString()}");
    }
  }

  Future<void> _onClipVolumeChanged(
    ClipVolumeChanged event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;

    if (currentState.selectedTrackId == null ||
        currentState.selectedClipId == null) {
      return;
    }

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == currentState.selectedTrackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == currentState.selectedClipId,
    );
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];

    if (clip is VideoClip) {
      track.clips[clipIndex] = clip.copyWith(volume: event.volume);
    } else if (clip is AudioClip) {
      track.clips[clipIndex] = clip.copyWith(volume: event.volume);
    } else {
      return; // Text has no volume
    }

    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  // --- NEW: Speed Handler ---
  Future<void> _onClipSpeedChanged(
    ClipSpeedChanged event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;

    if (currentState.selectedTrackId == null ||
        currentState.selectedClipId == null) {
      return;
    }

    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == currentState.selectedTrackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == currentState.selectedClipId,
    );
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];

    if (clip is! VideoClip) return; // Only Video Speed for now

    final oldSpeed = clip.speed;
    final newSpeed = event.speed;

    // Calculate new duration based on speed change
    // Duration = OriginalDuration / Speed
    // So: NewDuration = OldDuration * (OldSpeed / NewSpeed)
    final newDurationMicro =
        (clip.durationInMicroseconds * (oldSpeed / newSpeed)).round();

    final updatedClip = clip.copyWith(
      speed: newSpeed,
      durationInMicroseconds: newDurationMicro,
    );

    track.clips[clipIndex] = updatedClip;

    // --- RIPPLE LOGIC ---
    // If main track, shift subsequent clips
    if (track.type == TrackType.video) {
      int currentTimelinePos =
          updatedClip.startTimeInTimelineInMicroseconds + newDurationMicro;

      for (int i = clipIndex + 1; i < track.clips.length; i++) {
        final nextClip = track.clips[i] as VideoClip;
        track.clips[i] = nextClip.copyWith(
          startTimeInTimelineInMicroseconds: currentTimelinePos,
        );
        currentTimelinePos += nextClip.durationInMicroseconds;
      }
    }

    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
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

  Future<void> _onClipMoved(ClipMoved event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );

    // Main Video Track is not movable via drag-and-drop body
    if (track.type == TrackType.video) return;

    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final deltaMicro = event.delta.inMicroseconds;
    int newStartTime = clip.startTimeInTimelineInMicroseconds + deltaMicro;
    if (newStartTime < 0) newStartTime = 0;

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
      emit(
        currentState.copyWith(
          project: currentState.project,
          version: currentState.version + 1,
        ),
      );
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

    final originalClip = track.clips[clipIndex];
    TimelineClip? newClip;

    if (originalClip is TextClip) {
      newClip = originalClip.copyWith(
        offsetX: event.offsetX,
        offsetY: event.offsetY,
        scale: event.scale,
        rotation: event.rotation,
      );
    }
    // Ensure VideoClip is handled
    else if (originalClip is VideoClip) {
      newClip = originalClip.copyWith(
        offsetX: event.offsetX,
        offsetY: event.offsetY,
        scale: event.scale,
        rotation: event.rotation,
      );
    }

    if (newClip != null) {
      track.clips[clipIndex] = newClip;
      // Emit directly for performance (don't save to disk on every frame of drag)
      emit(
        currentState.copyWith(
          project: currentState.project,
          version: currentState.version + 1,
        ),
      );
    }
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

    if (clip is VideoClip) {
      VideoClip updatedClip = clip;
      if (event.isStartHandle) {
        final newStartTimeInSource =
            clip.startTimeInSourceInMicroseconds + deltaMicro;
        final maxDelta = clip.durationInMicroseconds - 500000;
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
    } else if (clip is TextClip) {
      TextClip updatedClip = clip;
      final minDuration = 500000;
      if (event.isStartHandle) {
        final newDuration = clip.durationInMicroseconds - deltaMicro;
        if (newDuration < minDuration) return;
        final newStartTime =
            clip.startTimeInTimelineInMicroseconds + deltaMicro;
        if (newStartTime < 0) return;
        updatedClip = clip.copyWith(
          startTimeInTimelineInMicroseconds: newStartTime,
          durationInMicroseconds: newDuration,
        );
      } else {
        final newDuration = clip.durationInMicroseconds + deltaMicro;
        if (newDuration < minDuration) return;
        updatedClip = clip.copyWith(durationInMicroseconds: newDuration);
      }
      track.clips[clipIndex] = updatedClip;
    }
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
    }
    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onClipTextUpdated(
    ClipTextUpdated event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;
    final track = currentState.project.tracks.firstWhere(
      (t) => t.id == event.trackId,
    );
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );
    if (clipIndex == -1) return;
    final oldClip = track.clips[clipIndex] as TextClip;
    final newClip = oldClip.copyWith(text: event.text, style: event.style);
    track.clips[clipIndex] = newClip;
    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onClipDeleted(
    ClipDeleted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;
    final trackIndex = currentState.project.tracks.indexWhere(
      (t) => t.id == event.trackId,
    );
    if (trackIndex == -1) return;
    final track = currentState.project.tracks[trackIndex];
    final clipIndex = track.clips.indexWhere(
      (c) => (c as TimelineClip).id == event.clipId,
    );
    if (clipIndex == -1) return;
    final clipToRemove = track.clips[clipIndex] as TimelineClip;
    final durationToRemove = clipToRemove.duration;
    track.clips.removeAt(clipIndex);
    if (track.type == TrackType.video) {
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
      if (track.clips.isEmpty) currentState.project.tracks.removeAt(trackIndex);
    }
    await currentState.project.save();
    emit(
      currentState.copyWith(
        project: currentState.project,
        clearSelectedClipId: true,
        clearSelectedTrackId: true,
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onProjectSaved(
    EditorProjectSaved event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    final project = currentState.project;
    final videoTrack = currentState.videoTrack;

    // OPTIMIZATION: Only generate thumbnail if one doesn't exist
    if (project.thumbnailPath == null && videoTrack.clips.isNotEmpty) {
      final firstClip = videoTrack.clips.first as VideoClip;
      try {
        // No need to deleteThumbnail if it is null
        project.thumbnailPath = await ThumbnailUtils.generateAndSaveThumbnail(
          firstClip.sourcePath,
          project.id,
        );
      } catch (e) {
        print("Error generating thumbnail on save: $e");
      }
    }

    // Update timestamp
    project.lastModified = DateTime.now();

    // CRITICAL: This calls Project.toJson(), which calls Track.toJson(),
    // which calls VideoClip.toJson().
    // If VideoClip.toJson() is missing the 'x/y/scale' fields, this save is incomplete.
    await project.save();

    // Emit the state to ensure UI reflects the saved status/thumbnail
    emit(currentState.copyWith(project: project));
  }

  Future<void> _onClipSplitRequested(
    ClipSplitRequested event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;
    EditorTrack? trackToSplit;
    TimelineClip? clipToSplit;
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
        thumbnailPath: originalClip.thumbnailPath,
      );
      final clipIndex = trackToSplit.clips.indexOf(originalClip);
      trackToSplit.clips[clipIndex] = clip1;
      trackToSplit.clips.insert(clipIndex + 1, clip2);
    } else if (clipToSplit is TextClip) {
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
    } else if (clipToSplit is AudioClip) {
      final originalClip = clipToSplit;
      final splitPointInTimeline = event.splitAt;
      final clip1Duration = splitPointInTimeline - originalClip.startTime;
      final clip2Duration = originalClip.endTime - splitPointInTimeline;
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
        version: currentState.version + 1,
      ),
    );
  }

  Future<void> _onClipAdded(ClipAdded event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
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
      final String clipId = const Uuid().v4();
      final String? thumbPath = await ThumbnailUtils.generateAndSaveThumbnail(
        event.videoFile.path,
        clipId,
      );
      final newClip = VideoClip(
        id: clipId,
        sourcePath: event.videoFile.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        startTimeInTimelineInMicroseconds: startTime.inMicroseconds,
        durationInMicroseconds: totalDuration.inMicroseconds,
        thumbnailPath: thumbPath,
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

  Future<void> _onAudioTrackAdded(
    AudioTrackAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
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
        startTimeInSourceInMicroseconds: 0,
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
    _saveToHistory(emit);
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
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;
    emit(currentState.copyWith(processingType: ProcessingType.export));
    try {
      final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());
      final String clipId = const Uuid().v4();
      final String? thumbPath = await ThumbnailUtils.generateAndSaveThumbnail(
        event.videoFile.path,
        clipId,
      );
      final newClip = VideoClip(
        id: clipId,
        sourcePath: event.videoFile.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        startTimeInTimelineInMicroseconds:
            currentState.videoPosition.inMicroseconds,
        durationInMicroseconds: totalDuration.inMicroseconds,
        thumbnailPath: thumbPath,
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

  Future<void> _onProjectCanvasRatioChanged(
    ProjectCanvasRatioChanged event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    _saveToHistory(emit);
    final currentState = state as EditorLoaded;

    // MANUAL COPY to support setting null
    final updatedProject = Project(
      id: currentState.project.id,
      lastModified: currentState.project.lastModified,
      tracks: currentState.project.tracks,
      thumbnailPath: currentState.project.thumbnailPath,
      canvasAspectRatio: event.ratio, // DIRECT ASSIGNMENT
    );

    final box = Hive.box<Project>('projects');
    await box.put(updatedProject.id, updatedProject);

    emit(
      currentState.copyWith(
        project: updatedProject,
        version: currentState.version + 1,
      ),
    );
  }
}
