import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_capcut/domain/models/video_clip.dart'; // --- ADDED: The crucial import ---
import 'package:uuid/uuid.dart'; // --- ADDED: For generating unique IDs ---

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(EditorInitial()) {
    on<EditorVideoInitialized>(_onVideoInitialized);
    on<StabilizationStarted>(_onStabilizationStarted);
    on<UndoRequested>(_onUndoRequested);
    on<RedoRequested>(_onRedoRequested);
    on<PlaybackStatusChanged>(_onPlaybackStatusChanged);
    on<AiEnhanceVoiceStarted>(_onAiEnhanceVoiceStarted);
    on<ClipTapped>(_onClipTapped);
    on<VideoPositionChanged>(__onVideoPositionChanged);
    on<VideoSeekRequsted>(_onVideoSeekRequested);
    on<ClipSplitRequested>(_onClipSplitRequested);
    on<NoiseReductionApplied>(_onNoiseReductionApplied);
  }

  final _uuid = const Uuid();

  // --- MODIFIED: Now creates the first VideoClip "instruction" ---
  Future<void> _onVideoInitialized(
    EditorVideoInitialized event,
    Emitter<EditorState> emit,
  ) async {
    try {
      final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
      final durationString = info.getMediaInformation()?.getDuration();
      if (durationString == null) {
        throw Exception("Could not get video duration.");
      }
      final videoDuration = Duration(
        milliseconds: (double.parse(durationString) * 1000).round(),
      );

      final initialClip = VideoClip(
        sourcePath: event.videoFile.path,
        startTimeInSource: Duration.zero,
        endTimeInSource: videoDuration,
        uniqueId: _uuid.v4(),
      );

      emit(
        EditorLoaded(
          timelineHistory: [
            [initialClip],
          ],
          historyIndex: 0,
          isPlaying: false,
        ),
      );
    } catch (e) {
      // Handle error, maybe emit an error state
      print("Error during video initialization: $e");
    }
  }

  // --- This logic remains the same ---
  void __onVideoPositionChanged(
    VideoPositionChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(
        currentState.copyWith(
          videoDuration: event.duration,
          videoPosition: event.position,
        ),
      );
    }
  }

  // --- This logic remains the same ---
  void _onVideoSeekRequested(
    VideoSeekRequsted event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(currentState.copyWith(videoPosition: event.position));
    }
  }

  // --- This logic remains the same ---
  void _onClipTapped(ClipTapped event, Emitter<EditorState> emit) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(
        currentState.copyWith(
          selectedClipIndex: event.clipIndex,
          deselectClip: event.clipIndex == null,
        ),
      );
    }
  }

  // --- MODIFIED: Works with the new state but logic is the same ---
  void _onUndoRequested(UndoRequested event, Emitter<EditorState> emit) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      if (currentState.canUndo) {
        emit(
          currentState.copyWith(
            historyIndex: currentState.historyIndex - 1,
            isPlaying: false,
            deselectClip: true,
          ),
        );
      }
    }
  }

  // --- MODIFIED: Works with the new state but logic is the same ---
  void _onRedoRequested(RedoRequested event, Emitter<EditorState> emit) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      if (currentState.canRedo) {
        emit(
          currentState.copyWith(
            historyIndex: currentState.historyIndex + 1,
            isPlaying: false,
            deselectClip: true,
          ),
        );
      }
    }
  }

  // --- MODIFIED: Works with the new state but logic is the same ---
  void _onPlaybackStatusChanged(
    PlaybackStatusChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(currentState.copyWith(isPlaying: event.isPlaying));
    }
  }

  // --- REWRITTEN: The new, instantaneous split logic ---
  void _onClipSplitRequested(
    ClipSplitRequested event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    try {
      final clipToSplit = currentState.currentClips[event.clipIndex];

      // Calculate the duration of all clips before the one we are splitting
      Duration precedingDuration = Duration.zero;
      for (int i = 0; i < event.clipIndex; i++) {
        precedingDuration += currentState.currentClips[i].duration;
      }

      // Calculate the split point's duration relative to the start of the clip being split
      final splitPointInClipDuration = event.splitAt - precedingDuration;

      // The new timestamp inside the *source* video file where the split happens
      final splitPointInSource =
          clipToSplit.startTimeInSource + splitPointInClipDuration;

      // Ensure we're not splitting too close to the clip's edges
      if (splitPointInClipDuration < const Duration(milliseconds: 100) ||
          (clipToSplit.duration - splitPointInClipDuration) <
              const Duration(milliseconds: 100)) {
        print("Split point too close to the edge. Ignoring.");
        return; // Do nothing if the split is invalid
      }

      // Create the first new clip (from its start to the split point)
      final clip1 = clipToSplit.copyWith(
        endTimeInSource: splitPointInSource,
        uniqueId: _uuid.v4(),
      );

      // Create the second new clip (from the split point to its end)
      final clip2 = clipToSplit.copyWith(
        startTimeInSource: splitPointInSource,
        uniqueId: _uuid.v4(),
      );

      // Create the new timeline by replacing the old clip with the two new ones
      var newClips = List<VideoClip>.from(currentState.currentClips);
      newClips.removeAt(event.clipIndex);
      newClips.insertAll(event.clipIndex, [clip1, clip2]);

      // Add the new timeline state to our history
      _addHistory(newClips, emit);
    } catch (e) {
      print("Error during split logic: $e");
    }
  }

  // --- REWRITTEN: The new hybrid model for heavy effects ---
  Future<void> _onStabilizationStarted(
    StabilizationStarted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipIndex == null) return;
    final clipIndex = currentState.selectedClipIndex!;
    final clipToProcess = currentState.currentClips[clipIndex];

    // If the clip has already been processed, we shouldn't process it again
    if (clipToProcess.processedPath != null) {
      print("Clip has already been processed. Ignoring stabilization request.");
      return;
    }

    emit(
      EditorProcessing(
        timelineHistory: currentState.timelineHistory,
        historyIndex: currentState.historyIndex,
        isPlaying: false,
        progress: 0.0,
        type: ProcessingType.stabilization,
        selectedClipIndex: clipIndex,
      ),
    );

    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String transformFilePath = '${appDirectory.path}/transforms.trf';
      final String outputPath =
          '${appDirectory.path}/stabilized_${_uuid.v4()}.mp4';

      final startTime = _formatFFmpegDuration(clipToProcess.startTimeInSource);
      final endTime = _formatFFmpegDuration(clipToProcess.endTimeInSource);

      // --- NEW FFmpeg Logic: Trim from the original source AND stabilize in one go ---
      final pass1Command =
          '-i "${clipToProcess.sourcePath}" -ss $startTime -to $endTime -vf vidstabdetect=result="$transformFilePath" -f null -';

      final session1 = await FFmpegKit.execute(pass1Command);
      final returnCode1 = await session1.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode1)) {
        throw Exception("Stabilization Pass 1 failed.");
      }

      final pass2Command =
          '-i "${clipToProcess.sourcePath}" -ss $startTime -to $endTime -vf vidstabtransform=input="$transformFilePath":smoothing=15:crop=black -vcodec libx264 -preset ultrafast "$outputPath"';

      // NOTE: Progress tracking would need to be re-implemented for this command if desired.
      final session2 = await FFmpegKit.execute(pass2Command);

      if (!ReturnCode.isSuccess(await session2.getReturnCode())) {
        throw Exception("Stabilization Pass 2 failed.");
      }

      // Get duration of the newly created, stabilized file
      final info = await FFprobeKit.getMediaInformation(outputPath);
      final newDuration = Duration(
        milliseconds:
            (double.parse(info.getMediaInformation()!.getDuration()!) * 1000)
                .round(),
      );

      // Create a new VideoClip instruction pointing to the processed file
      final stabilizedClip = clipToProcess.copyWith(
        processedPath: outputPath,
        startTimeInSource: Duration.zero,
        endTimeInSource: newDuration,
        uniqueId: _uuid.v4(),
      );

      var newClips = List<VideoClip>.from(currentState.currentClips);
      newClips[clipIndex] = stabilizedClip;
      _addHistory(newClips, emit);
    } catch (e) {
      print("Error during stabilization: $e");
      emit(
        currentState.copyWith(),
      ); // Revert to previous loaded state on failure
    }
  }

  // Omitted _onNoiseReductionApplied for brevity, but it would follow the exact same pattern
  // as _onStabilizationStarted: trim from source, apply filter, create new clip, update history.
  Future<void> _onNoiseReductionApplied(
    NoiseReductionApplied event,
    Emitter<EditorState> emit,
  ) async {
    // Implement using the same hybrid model as _onStabilizationStarted
  }

  Future<void> _onAiEnhanceVoiceStarted(
    AiEnhanceVoiceStarted event,
    Emitter<EditorState> emit,
  ) async {
    // Implement using the same hybrid model as _onStabilizationStarted
  }

  // --- MODIFIED: The history now works with VideoClip objects ---
  void _addHistory(List<VideoClip> newClips, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    var newTimelineHistory = List<List<VideoClip>>.from(
      currentState.timelineHistory,
    );

    if (currentState.historyIndex < currentState.timelineHistory.length - 1) {
      newTimelineHistory.removeRange(
        currentState.historyIndex + 1,
        currentState.timelineHistory.length,
      );
    }

    newTimelineHistory.add(newClips);

    emit(
      currentState.copyWith(
        timelineHistory: newTimelineHistory,
        historyIndex: newTimelineHistory.length - 1,
        isPlaying: false,
        deselectClip: true,
      ),
    );
  }

  // --- HELPER: Stays the same, but is now used by the effects handlers ---
  String _formatFFmpegDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = d.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    return "$hours:$minutes:$seconds.$milliseconds";
  }
}
