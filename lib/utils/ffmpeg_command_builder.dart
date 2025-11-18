// lib/utils/ffmpeg_command_builder.dart
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';

class FFmpegCommandBuilder {
  final List<String> _inputs = [];
  final StringBuffer _filterComplex = StringBuffer();
  final Map<String, int> _videoPathMap = {};
  final Map<String, int> _audioPathMap = {};

  /// Adds a unique video file as an input source for FFmpeg.
  void addVideoInput(String path) {
    if (!_videoPathMap.containsKey(path)) {
      _videoPathMap[path] = _videoPathMap.length;
      _inputs.add('-i "$path"');
    }
  }

  /// Adds a unique audio file as an input source for FFmpeg.
  void addAudioInput(String path) {
    if (!_audioPathMap.containsKey(path)) {
      // Indexing continues after the video inputs
      _audioPathMap[path] = _videoPathMap.length + _audioPathMap.length;
      _inputs.add('-i "$path"');
    }
  }

  /// Processes all video clips to trim, adjust speed/volume, and concatenate them.
  void processVideoClips(List<VideoClip> clips) {
    final videoStreams = StringBuffer();
    final baseAudioStreams = StringBuffer();

    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final inputIndex = _videoPathMap[clip.playablePath]!;

      // Trim video and audio, set presentation timestamp (PTS)
      _filterComplex.writeln(
        '[$inputIndex:v]trim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},setpts=PTS-STARTPTS[v$i];',
      );
      _filterComplex.writeln(
        '[$inputIndex:a]atrim=start=${clip.startTimeInSource.inSeconds}.${clip.startTimeInSource.inMilliseconds.remainder(1000)}:end=${clip.endTimeInSource.inSeconds}.${clip.endTimeInSource.inMilliseconds.remainder(1000)},asetpts=PTS-STARTPTS,volume=${clip.volume}[a$i];',
      );

      // Note: Applying speed via `atempo` and `setpts` is complex and was not in the original
      // logic, so we are keeping it consistent. The duration is already calculated based on speed.

      videoStreams.write('[v$i]');
      baseAudioStreams.write('[a$i]');
    }

    // Concatenate all processed video and audio segments
    _filterComplex.writeln(
      '${videoStreams}concat=n=${clips.length}:v=1:a=0[vid_out];',
    );
    _filterComplex.writeln(
      '${baseAudioStreams}concat=n=${clips.length}:v=0:a=1[base_audio];',
    );
  }

  /// Processes additional audio clips to delay, adjust volume, and prepare for mixing.
  void processAudioClips(List<AudioClip> clips) {
    if (clips.isEmpty) {
      // If no extra audio, just pass the base audio through
      _filterComplex.writeln('[base_audio]acopy[final_audio];');
      return;
    }

    final mixStreams = StringBuffer('[base_audio]');
    for (int i = 0; i < clips.length; i++) {
      final audioClip = clips[i];
      final inputIndex = _audioPathMap[audioClip.filePath]!;
      final delayMs = audioClip.startTimeInTimeline.inMilliseconds;
      // final delayMs = audioClip.startTimeInTimeline.inMilliseconds;

      // Apply delay and volume to the additional audio track
      _filterComplex.writeln(
        '[$inputIndex:a]adelay=$delayMs|$delayMs,volume=${audioClip.volume}[aud$i];',
      );
      mixStreams.write('[aud$i]');
    }

    // Mix the base audio with all the additional audio tracks
    final totalAudioInputs = clips.length + 1;
    _filterComplex.writeln(
      '${mixStreams}amix=inputs=$totalAudioInputs[final_audio];',
    );
  }

  /// Applies final output settings like resolution and frame rate.
  void applyOutputSettings(ExportSettings settings) {
    _filterComplex.writeln(
      '[vid_out]scale=-2:${settings.resolution},fps=${settings.frameRate}[final_video];',
    );
  }

  /// Builds the final, complete FFmpeg command string.
  String build(String outputPath) {
    final bitrate = (_codeRateValue == 0)
        ? "5M"
        : (_codeRateValue == 1 ? "10M" : "15M");

    final commandParts = [
      _inputs.join(' '),
      '-filter_complex "${_filterComplex.toString()}"',
      '-map "[final_video]"',
      '-map "[final_audio]"',
      '-c:v libx264',
      '-preset veryfast',
      '-b:v $bitrate',
      '-c:a aac',
      '-y "$outputPath"',
    ];

    return commandParts.join(' ');
  }

  // Helper to get bitrate from settings, assuming it's a property of ExportSettings
  double get _codeRateValue {
    // This is a placeholder. You'd get this from the ExportSettings object.
    // For now, let's assume 'Recommended'
    return 1.0;
  }
}
