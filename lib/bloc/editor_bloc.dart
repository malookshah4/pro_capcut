// lib/bloc/editor_bloc.dart
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
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:uuid/uuid.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(EditorInitial()) {
    on<EditorProjectLoaded>(_onProjectLoaded); // UPDATED
    on<ClipAdded>(_onClipAdded);
    on<StabilizationStarted>(_onStabilizationStarted);
    on<UndoRequested>(_onUndoRequested);
    on<RedoRequested>(_onRedoRequested);
    on<PlaybackStatusChanged>(_onPlaybackStatusChanged);
    on<AiEnhanceVoiceStarted>(_onAiEnhanceVoiceStarted);
    on<ClipTapped>(_onClipTapped);
    on<VideoPositionChanged>(_onVideoPositionChanged);
    on<VideoSeekRequsted>(_onVideoSeekRequested);
    on<ClipSplitRequested>(_onClipSplitRequested);
    on<NoiseReductionApplied>(_onNoiseReductionApplied);
    on<ClipDeleted>(_onClipDeleted);
    on<ExportStarted>(_onExportStarted);
    on<ClipSpeedChanged>(_onClipSpeedChanged);
    on<ClipTrimmed>(_onClipTrimmed);
    on<ClipTrimEnded>(_onClipTrimEnded);
    on<AudioExtractedAndAdded>(_onAudioExtractedAndAdded);
    on<ClipVolumeChanged>(_onClipVolumeChanged);
  }

  void _addHistory(
    EditorLoaded currentState,
    List<VideoClip> newClips,
    Emitter<EditorState> emit,
  ) {
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

  void _onClipVolumeChanged(
    ClipVolumeChanged event,
    Emitter<EditorState> emit,
  ) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipIndex == null) return;

    final clipIndex = currentState.selectedClipIndex!;
    final clipToChange = currentState.currentClips[clipIndex];

    // Create a new clip instance with the updated volume
    final newClip = clipToChange.copyWith(volume: event.newVolume);

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips[clipIndex] = newClip;

    // Use the existing _addHistory method to save the change to the undo/redo stack
    _addHistory(currentState, newClips, emit);
  }

  void _onProjectLoaded(EditorProjectLoaded event, Emitter<EditorState> emit) {
    final totalDuration = event.project.videoClips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );

    emit(
      EditorLoaded(
        projectId: event.project.id,
        timelineHistory: [event.project.videoClips],
        historyIndex: 0,
        isPlaying: false,
        videoDuration: totalDuration,
        audioClips: event.project.audioClips,
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
    final totalDuration = Duration(milliseconds: durationMs.round());

    final newClip = VideoClip(
      sourcePath: event.videoFile.path,
      sourceDurationInMicroseconds:
          totalDuration.inMicroseconds, // Use microseconds
      startTimeInSourceInMicroseconds:
          Duration.zero.inMicroseconds, // Use microseconds
      endTimeInSourceInMicroseconds:
          totalDuration.inMicroseconds, // Use microseconds
      uniqueId: const Uuid().v4(),
    );

    final newClips = List<VideoClip>.from(currentState.currentClips)
      ..add(newClip);
    _addHistory(currentState, newClips, emit);
  }

  void _onVideoPositionChanged(
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
    _addHistory(currentState, newClips, emit);
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
      return;
    }

    final splitPointInSource = clipToSplit.startTimeInSource + splitPointInClip;

    final clip1 = clipToSplit.copyWith(
      endTimeInSourceInMicroseconds: splitPointInSource.inMicroseconds,
      uniqueId: const Uuid().v4(),
    );
    final clip2 = clipToSplit.copyWith(
      startTimeInSourceInMicroseconds: splitPointInSource.inMicroseconds,
      uniqueId: const Uuid().v4(),
    );

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips.removeAt(event.clipIndex);
    newClips.insertAll(event.clipIndex, [clip1, clip2]);
    _addHistory(currentState, newClips, emit);
  }

  void _onClipSpeedChanged(ClipSpeedChanged event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.selectedClipIndex == null) return;
    final clipIndex = currentState.selectedClipIndex!;

    final clipToChange = currentState.currentClips[clipIndex];
    final newClip = clipToChange.copyWith(speed: event.newSpeed);

    final newClips = List<VideoClip>.from(currentState.currentClips);
    newClips[clipIndex] = newClip;
    _addHistory(currentState, newClips, emit);
  }

  Future<void> _onStabilizationStarted(
    StabilizationStarted event,
    Emitter<EditorState> emit,
  ) async {
    // Implement using hybrid model as before...
  }

  Future<void> _onNoiseReductionApplied(
    NoiseReductionApplied event,
    Emitter<EditorState> emit,
  ) async {
    // Implement using hybrid model...
  }

  Future<void> _onAiEnhanceVoiceStarted(
    AiEnhanceVoiceStarted event,
    Emitter<EditorState> emit,
  ) async {
    // Implement using hybrid model...
  }

  Future<void> _onExportStarted(
    ExportStarted event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    if (currentState.currentClips.isEmpty) return;

    final totalDuration = currentState.videoDuration;

    emit(
      EditorProcessing(
        projectId: currentState.projectId,
        timelineHistory: currentState.timelineHistory,
        historyIndex: currentState.historyIndex,
        isPlaying: false,
        progress: 0.0,
        type: ProcessingType.export,
        audioClips: currentState.audioClips,
      ),
    );

    final completer = Completer<void>();
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String outputPath =
        '${appDirectory.path}/exported_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // --- Building the command ---
    final inputs = <String>[];
    final videoPaths = currentState.currentClips
        .map((c) => c.playablePath)
        .toSet();
    final audioPaths = currentState.audioClips.map((c) => c.filePath).toSet();

    for (final path in videoPaths) {
      inputs.add('-i "$path"');
    }
    for (final path in audioPaths) {
      inputs.add('-i "$path"');
    }

    final filterComplex = StringBuffer();

    // --- THIS IS THE CORRECTED PART ---
    final videoPathList = videoPaths.toList();
    final audioPathList = audioPaths.toList();

    // Create a map from the file path to its input index (e.g., {"/path/to/vid.mp4": 0})
    final videoMap = {
      for (int i = 0; i < videoPathList.length; i++) videoPathList[i]: i,
    };
    final audioMap = {
      for (int i = 0; i < audioPathList.length; i++)
        audioPathList[i]: i + videoPathList.length,
    };
    // --- END CORRECTION ---

    // 1. Process and concatenate video clips

    final videoStreams = StringBuffer();
    final baseAudioStreams = StringBuffer();
    for (int i = 0; i < currentState.currentClips.length; i++) {
      final clip = currentState.currentClips[i];
      final inputIndex = videoMap[clip.playablePath]!;
      filterComplex.write(
        '[$inputIndex:v]trim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},setpts=PTS-STARTPTS[v$i];',
      );

      filterComplex.write(
        '[${inputIndex}:a]atrim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},asetpts=PTS-STARTPTS,volume=${clip.volume}[a$i];',
      );

      videoStreams.write('[v$i]');
      baseAudioStreams.write('[a$i]');
    }
    filterComplex.write(
      '${videoStreams}concat=n=${currentState.currentClips.length}:v=1:a=0[vid_out];',
    );
    filterComplex.write(
      '${baseAudioStreams}concat=n=${currentState.currentClips.length}:v=0:a=1[base_audio];',
    );

    // 2. Process and mix additional audio clips
    final mixStreams = StringBuffer('[base_audio]');
    for (int i = 0; i < currentState.audioClips.length; i++) {
      final audioClip = currentState.audioClips[i];
      final inputIndex = audioMap[audioClip.filePath]!;
      final delayMs = audioClip.startTimeInTimeline.inMilliseconds;

      // ✨ FIX: Add the ",volume=${audioClip.volume}" filter to the additional audio streams.
      filterComplex.write(
        '[$inputIndex:a]adelay=${delayMs}|${delayMs},volume=${audioClip.volume}[aud$i];',
      );
      mixStreams.write('[aud$i]');
    }
    final totalAudioInputs = currentState.audioClips.length + 1;
    filterComplex.write(
      '${mixStreams}amix=inputs=$totalAudioInputs[final_audio];',
    );

    // 3. Apply export settings
    final resolution = event.settings.resolution;
    final frameRate = event.settings.frameRate;
    final bitrate = (event.settings.codeRate == 0)
        ? "5M"
        : (event.settings.codeRate == 1 ? "10M" : "15M");

    filterComplex.write(
      '[vid_out]scale=-2:$resolution,fps=$frameRate[final_video];',
    );

    final command =
        '${inputs.join(' ')} -filter_complex "${filterComplex.toString()}" -map "[final_video]" -map "[final_audio]" -c:v libx264 -preset veryfast -b:v $bitrate -c:a aac -y "$outputPath"';

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          try {
            final hasPermissions = await Gal.hasAccess();
            if (!hasPermissions) {
              await Gal.requestAccess();
            }
            await Gal.putVideo(outputPath, album: 'FreeCut');
          } catch (e) {
            print("Error saving video to gallery: $e");
          }
        } else {
          print(
            "Export FAILED. FFmpeg logs: ${await session.getLogsAsString()}",
          );
        }
        emit(currentState.copyWith());
        completer.complete();
      },
      null,
      (statistics) {
        final progress = (statistics.getTime() / totalDuration.inMilliseconds);
        if (!isClosed) {
          emit(
            EditorProcessing(
              projectId: currentState.projectId,
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
    if (currentState.liveClips != null) {
      _addHistory(currentState, currentState.liveClips!, emit);
    }
  }

  void _onClipTrimmed(ClipTrimmed event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;

    final liveClips = currentState.liveClips ?? currentState.currentClips;
    final clipToTrim = liveClips[event.clipIndex];

    var updatedStart = clipToTrim.startTimeInSource;
    var updatedEnd = clipToTrim.endTimeInSource;

    if (event.newStart != null) updatedStart = event.newStart!;
    if (event.newEnd != null) updatedEnd = event.newEnd!;

    // Boundary checks
    if (updatedStart < Duration.zero) updatedStart = Duration.zero;
    if (updatedEnd > clipToTrim.sourceDuration)
      updatedEnd = clipToTrim.sourceDuration;
    if (updatedEnd - updatedStart < const Duration(milliseconds: 100)) {
      if (event.newStart != null) {
        updatedStart = updatedEnd - const Duration(milliseconds: 100);
      } else {
        updatedEnd = updatedStart + const Duration(milliseconds: 100);
      }
    }

    final trimmedClip = clipToTrim.copyWith(
      startTimeInSourceInMicroseconds: updatedStart.inMicroseconds,
      endTimeInSourceInMicroseconds: updatedEnd.inMicroseconds,
    );

    final newLiveClips = List<VideoClip>.from(liveClips);
    newLiveClips[event.clipIndex] = trimmedClip;

    emit(currentState.copyWith(liveClips: newLiveClips));
  }

  Future<void> _onAudioExtractedAndAdded(
    AudioExtractedAndAdded event,
    Emitter<EditorState> emit,
  ) async {
    if (state is! EditorLoaded) return;
    final currentState = state as EditorLoaded;
    // It's good practice to show the user something is happening.
    emit(currentState.copyWith(isPlaying: false)); // Pauses playback

    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputPath =
          '${appDirectory.path}/extracted_audio_${const Uuid().v4()}.m4a';

      // ✨ FIX: Change the audio codec flag from 'aac' to 'copy'.
      final command =
          '-i "${event.videoFile.path}" -vn -c:a copy -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final info = await FFprobeKit.getMediaInformation(outputPath);
        final durationMs =
            (double.tryParse(
                  info.getMediaInformation()?.getDuration() ?? '0',
                ) ??
                0) *
            1000;
        final audioDuration = Duration(milliseconds: durationMs.round());

        final newAudioClip = AudioClip(
          filePath: outputPath,
          uniqueId: const Uuid().v4(),
          durationInMicroseconds: audioDuration.inMicroseconds,
          startTimeInTimelineInMicroseconds:
              currentState.videoPosition.inMicroseconds,
        );

        final newAudioClips = List<AudioClip>.from(currentState.audioClips)
          ..add(newAudioClip);

        emit(currentState.copyWith(audioClips: newAudioClips));
      } else {
        // ✨ BEST PRACTICE: Print the full FFmpeg logs on failure.
        print('FFmpeg failed to extract audio. Return code: $returnCode');
        print('FFmpeg logs: ${await session.getLogsAsString()}');
        // Optionally, show an error message to the user here.
      }
    } catch (e) {
      print("Error extracting audio: $e");
      // Re-emit the original state to clear any loading indicators.
      emit(currentState.copyWith());
    }
  }
}
