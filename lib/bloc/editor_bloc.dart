import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:uuid/uuid.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(EditorInitial()) {
    on<EditorVideoInitialized>(_onVideoInitialized);
    on<ClipAdded>(_onClipAdded);
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
    on<ClipDeleted>(_onClipDeleted);
    on<ExportStarted>(_onExportStarted);
    on<ClipSpeedChanged>(_onClipSpeedChanged);
    on<ClipTrimmed>(_onClipTrimmed);
    on<ClipTrimEnded>(_onClipTrimEnded);
    on<AudioExtractedAndAdded>(_onAudioExtractedAndAdded);
  }

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

    final newTotalDuration = newClips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );

    emit(
      currentState.copyWith(
        timelineHistory: newTimelineHistory,
        historyIndex: newTimelineHistory.length - 1,
        isPlaying: false,
        deselectClip: true,
        videoDuration: newTotalDuration,
      ),
    );
  }

  Future<void> _onVideoInitialized(
    EditorVideoInitialized event,
    Emitter<EditorState> emit,
  ) async {
    final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
    final durationMs =
        (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
            0) *
        1000;
    final totalDuration = Duration(milliseconds: durationMs.round());

    final initialClip = VideoClip(
      sourcePath: event.videoFile.path,
      sourceDuration: totalDuration,
      startTimeInSource: Duration.zero,
      endTimeInSource: Duration(milliseconds: durationMs.round()),
      uniqueId: const Uuid().v4(),
    );

    emit(
      EditorLoaded(
        timelineHistory: [
          [initialClip],
        ],
        historyIndex: 0,
        isPlaying: false,
        videoDuration: initialClip.duration,
      ),
    );
  }

  Future<void> _onClipAdded(ClipAdded event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final info = await FFprobeKit.getMediaInformation(event.videoFile.path);
    final durationMs =
        (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
            0) *
        1000;
    final totalDuration = Duration(
      milliseconds: durationMs.round(),
    ); // <-- Use this

    final newClip = VideoClip(
      sourcePath: event.videoFile.path,
      sourceDuration: totalDuration,
      startTimeInSource: Duration.zero,
      endTimeInSource: Duration(milliseconds: durationMs.round()),
      uniqueId: const Uuid().v4(),
    );

    final newClips = List<VideoClip>.from(currentState.currentClips)
      ..add(newClip);
    _addHistory(newClips, emit);
  }

  void __onVideoPositionChanged(
    VideoPositionChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(currentState.copyWith(videoPosition: event.position));
    }
  }

  void _onVideoSeekRequested(
    VideoSeekRequsted event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(currentState.copyWith(videoPosition: event.position));
    }
  }

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

  void _onPlaybackStatusChanged(
    PlaybackStatusChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      emit(currentState.copyWith(isPlaying: event.isPlaying));
    }
  }

  void _onClipDeleted(ClipDeleted event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipIndex == null) return;

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips.removeAt(currentState.selectedClipIndex!);
    _addHistory(newClips, emit);
  }

  void _onClipSplitRequested(
    ClipSplitRequested event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    Duration precedingDuration = Duration.zero;
    for (int i = 0; i < event.clipIndex; i++) {
      precedingDuration += currentState.currentClips[i].duration;
    }

    final clipToSplit = currentState.currentClips[event.clipIndex];
    final splitPointInClip = event.splitAt - precedingDuration;

    if (splitPointInClip <= const Duration(milliseconds: 100) ||
        (clipToSplit.duration - splitPointInClip) <=
            const Duration(milliseconds: 100)) {
      emit(currentState.copyWith());
      return;
    }

    final splitPointInSource = clipToSplit.startTimeInSource + splitPointInClip;

    final clip1 = clipToSplit.copyWith(
      endTimeInSource: splitPointInSource,
      uniqueId: const Uuid().v4(),
    );
    final clip2 = clipToSplit.copyWith(
      startTimeInSource: splitPointInSource,
      uniqueId: const Uuid().v4(),
    );

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips.removeAt(event.clipIndex);
    newClips.insertAll(event.clipIndex, [clip1, clip2]);
    _addHistory(newClips, emit);
  }

  void _onClipSpeedChanged(ClipSpeedChanged event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipIndex == null) return;
    final clipIndex = currentState.selectedClipIndex!;

    final clipToChange = currentState.currentClips[clipIndex];

    // Speed change is now non-destructive. We just update the instruction.
    final newClip = clipToChange.copyWith(
      speed: event.newSpeed,
      processedPath: null, // Clear any previous processing
    );

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips[clipIndex] = newClip;
    _addHistory(newClips, emit);
  }

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
          '${appDirectory.path}/stabilized_${const Uuid().v4()}.mp4';

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
        uniqueId: const Uuid().v4(),
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

  Future<void> _onExportStarted(
    ExportStarted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.currentClips.isEmpty) return;

    final totalDuration = currentState.currentClips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );

    emit(
      EditorProcessing(
        timelineHistory: currentState.timelineHistory,
        historyIndex: currentState.historyIndex,
        isPlaying: false,
        progress: 0.0,
        type: ProcessingType.export,
      ),
    );

    final completer = Completer<void>();
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String outputPath =
        '${appDirectory.path}/exported_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // --- This complex FFmpeg command generation remains the same ---
    final inputs = <String>[];
    final filterComplex = StringBuffer();
    final concatStreams = StringBuffer();
    final uniquePaths = <String>{};
    final pathMap = <String, int>{};

    for (var clip in currentState.currentClips) {
      if (!uniquePaths.contains(clip.playablePath)) {
        pathMap[clip.playablePath] = uniquePaths.length;
        uniquePaths.add(clip.playablePath);
      }
    }
    inputs.addAll(uniquePaths.map((path) => '-i "$path"'));

    for (int i = 0; i < currentState.currentClips.length; i++) {
      final clip = currentState.currentClips[i];
      final inputIndex = pathMap[clip.playablePath]!;

      filterComplex.write(
        '[$inputIndex:v]trim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},setpts=PTS-STARTPTS[v$i];',
      );
      filterComplex.write(
        '[$inputIndex:a]atrim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},asetpts=PTS-STARTPTS[a$i];',
      );

      concatStreams.write('[v$i][a$i]');
    }

    filterComplex.write(
      '${concatStreams}concat=n=${currentState.currentClips.length}:v=1:a=1[outv][outa]',
    );

    final command =
        '${inputs.join(' ')} -filter_complex "${filterComplex.toString()}" -map "[outv]" -map "[outa]" -c:v libx264 -preset medium -c:a aac "$outputPath"';

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          print("Export SUCCESSFUL! Video temporarily saved at: $outputPath");

          // --- NEW: Logic to save the video to the device's gallery ---
          try {
            // The package handles requesting permission if it hasn't been granted.
            final hasPermissions = await Gal.hasAccess();
            if (!hasPermissions) {
              await Gal.requestAccess();
            }
            // Save the video to a specific album named 'FreeCut' for a professional feel.
            await Gal.putVideo(outputPath, album: 'FreeCut');
            print("Video successfully saved to Gallery in 'FreeCut' album!");
          } catch (e) {
            print("Error saving video to gallery: $e");
          }
        } else {
          print(
            "Export FAILED. FFmpeg logs: ${await session.getLogsAsString()}",
          );
        }

        // Return to the loaded state whether the export/save succeeds or fails
        emit(currentState.copyWith());
        completer.complete();
      },
      null, // Log callback
      (statistics) {
        final progress = statistics.getTime() / totalDuration.inMilliseconds;
        if (!isClosed) {
          emit(
            EditorProcessing(
              timelineHistory: currentState.timelineHistory,
              historyIndex: currentState.historyIndex,
              isPlaying: false,
              progress: progress.clamp(0.0, 1.0),
              type: ProcessingType.export,
            ),
          );
        }
      },
    );

    return completer.future;
  }

  void _onClipTrimEnded(ClipTrimEnded event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    // If there's a live state from trimming, this saves it to the
    // official undo/redo history and clears the live state.
    if (currentState.liveClips != null) {
      _addHistory(currentState.liveClips!, emit);
    }
  }

  void _onClipTrimmed(ClipTrimmed event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final clipToTrim = currentState.currentClips[event.clipIndex];

    // VVVVVV THIS IS THE CORRECTED LOGIC VVVVVV
    // 1. Initialize local variables with the clip's current values.
    var updatedStart = clipToTrim.startTimeInSource;
    var updatedEnd = clipToTrim.endTimeInSource;

    // 2. Apply the new start or end time from the event.
    if (event.newStart != null) {
      updatedStart = event.newStart!;
    } else if (event.newEnd != null) {
      updatedEnd = event.newEnd!;
    }

    // 3. Enforce trimming rules on the local variables.
    if (updatedStart < Duration.zero) {
      updatedStart = Duration.zero;
    }
    if (updatedEnd > clipToTrim.sourceDuration) {
      updatedEnd = clipToTrim.sourceDuration;
    }
    if (updatedEnd - updatedStart < const Duration(milliseconds: 100)) {
      if (event.newStart != null) {
        updatedStart = updatedEnd - const Duration(milliseconds: 100);
      } else {
        updatedEnd = updatedStart + const Duration(milliseconds: 100);
      }
    }
    // ^^^^^^ THIS IS THE CORRECTED LOGIC ^^^^^^

    // Create the updated clip using the corrected local variables.
    final trimmedClip = clipToTrim.copyWith(
      startTimeInSource: updatedStart,
      endTimeInSource: updatedEnd,
    );

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips[event.clipIndex] = trimmedClip;

    emit(currentState.copyWith(liveClips: newClips));
  }

  Future<void> _onAudioExtractedAndAdded(
    AudioExtractedAndAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    // 1. Show a processing state to the user
    emit(
      EditorProcessing(
        // You can create a new ProcessingType for this if you want
        type: ProcessingType.export,
        progress: 0.0, // Or make it indeterminate
        // copy other properties from currentState...
        timelineHistory: currentState.timelineHistory,
        historyIndex: currentState.historyIndex,
        isPlaying: false,
      ),
    );

    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      // 2. Define the output path for our new audio file
      final String outputPath =
          '${appDirectory.path}/extracted_audio_${const Uuid().v4()}.m4a';

      // 3. Construct the FFmpeg command
      // -i: input file
      // -vn: "no video", strips the video stream
      // -c:a aac: uses the high-quality AAC audio codec
      final command =
          '-i "${event.videoFile.path}" -vn -acodec aac -b:a 192k -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // 4. Get the duration of the newly created audio file
        final info = await FFprobeKit.getMediaInformation(outputPath);
        final durationMs =
            (double.tryParse(
                  info.getMediaInformation()?.getDuration() ?? '0',
                ) ??
                0) *
            1000;
        final audioDuration = Duration(milliseconds: durationMs.round());

        // 5. Create the new AudioClip model
        final newAudioClip = AudioClip(
          filePath: outputPath,
          uniqueId: const Uuid().v4(),
          duration: audioDuration,
          // It starts at the current playhead position
          startTimeInTimeline: currentState.videoPosition,
        );

        // 6. Add it to the list and update the state
        final newAudioClips = List<AudioClip>.from(currentState.audioClips)
          ..add(newAudioClip);

        // We use copyWith here instead of _addHistory because adding audio
        // is often considered a non-destructive layering action, not an undoable "edit"
        // to the main timeline. You can change this to _addHistory if you prefer.
        emit(currentState.copyWith(audioClips: newAudioClips));
      } else {
        throw Exception("FFmpeg failed to extract audio.");
      }
    } catch (e) {
      print("Error extracting audio: $e");
      // On failure, return to the previous loaded state
      emit(currentState.copyWith());
    }
  }
}
