import 'dart:io';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';

class FFmpegCommandBuilder {
  final List<String> _inputs = [];
  final List<String> _filterChains = [];
  int _streamCount = 0;
  bool _hasMainVideo = false;
  double _totalVideoDuration = 0.0; // Track total duration for audio sync

  // Detect Platform for Hardware Acceleration
  bool get _isAndroid => Platform.isAndroid;
  bool get _isIOS => Platform.isIOS;

  // --- 1. Main Video ---
  void setMainVideo(List<VideoClip> clips, Map<String, bool> hasAudioMap) {
    if (clips.isEmpty) {
      _filterChains.add(
        "color=s=1080x1920:d=5:rate=30[c_v];anullsrc=cl=stereo:r=44100:d=5[c_a]",
      );
      _hasMainVideo = true;
      _totalVideoDuration = 5.0;
      return;
    }

    final concatInputs = StringBuffer();
    List<String> videoStreams = [];
    List<String> audioStreams = [];
    _totalVideoDuration = 0.0;

    for (var clip in clips) {
      final idx = _addInput(clip.sourcePath);
      final hasAudio = hasAudioMap[clip.sourcePath] ?? false;

      final startSec = clip.startTimeInSourceInMicroseconds / 1000000.0;
      final endSec = clip.endTimeInSourceInMicroseconds / 1000000.0;
      final clipDuration =
          (clip.endTimeInSourceInMicroseconds -
              clip.startTimeInSourceInMicroseconds) /
          1000000.0;

      // Calculate active duration in timeline (considering speed)
      _totalVideoDuration += (clipDuration / clip.speed);

      final ptsMult = 1.0 / clip.speed;
      final vName = "v${_streamCount}";
      final aName = "a${_streamCount}";
      _streamCount++;

      // CapCut Optimization: Scale immediately to reduce memory usage
      // We use 'setsar=1' to prevent aspect ratio distortion issues on some players
      _filterChains.add(
        "[$idx:v]scale=1080:1920:force_original_aspect_ratio=decrease:flags=bicubic," // bicubic is faster than lanczos
        "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,"
        "setsar=1,"
        "trim=start=$startSec:end=$endSec,"
        "setpts=${ptsMult}*PTS,"
        "format=yuv420p[$vName]",
      );
      videoStreams.add("[$vName]");

      if (hasAudio) {
        _filterChains.add(
          "[$idx:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,"
          "atrim=start=$startSec:end=$endSec,"
          "asetpts=PTS-STARTPTS,"
          "volume=${clip.volume}[$aName]",
        );
        audioStreams.add("[$aName]");
      } else {
        // Generate silent audio for this specific clip duration
        _filterChains.add(
          "anullsrc=cl=stereo:r=44100:d=${clipDuration / clip.speed},"
          "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[$aName]",
        );
        audioStreams.add("[$aName]");
      }

      concatInputs.write("[$vName][$aName]");
    }

    // Optimization: Add 'unsafe=1' to concat for speed if formats are similar,
    // but safe=0 is standard.
    if (clips.length > 1) {
      _filterChains.add(
        "${concatInputs}concat=n=${clips.length}:v=1:a=1[base_v][base_a]",
      );
    } else {
      _filterChains.add("${videoStreams[0]}copy[base_v]");
      _filterChains.add("${audioStreams[0]}acopy[base_a]");
    }

    _hasMainVideo = true;
  }

  // --- 2. Overlays & Text (Fixed Position/Rotation) ---
  void addOverlays(List<VideoClip> overlays) {
    if (overlays.isEmpty || !_hasMainVideo) {
      _filterChains.add("[base_v]copy[final_v]");
      return;
    }

    String currentVideo = "base_v";

    for (int i = 0; i < overlays.length; i++) {
      final clip = overlays[i];
      final isImage =
          clip.sourcePath.toLowerCase().endsWith('.png') ||
          clip.sourcePath.toLowerCase().endsWith('.jpg');

      // 1. Add Input
      final idx = _addInput(clip.sourcePath, isImage: isImage);

      // 2. Prepare Timing
      final startTime = clip.startTimeInTimelineInMicroseconds / 1000000.0;
      final duration = (clip.durationInMicroseconds / 1000000.0) / clip.speed;
      final endTime = startTime + duration;

      // 3. Define Node Names
      final scaledName = "v_scaled_$i";
      final rotatedName = "v_rotated_$i";
      final outputName = "v_out_$i";

      // 4. Build Filter Chain: Scale -> Rotate -> Overlay

      // A. SCALE
      // We use -1 to maintain aspect ratio if only one dim is scaled,
      // or specific dims if you have them. Here we scale relative to input size.
      _filterChains.add("[$idx:v]scale=iw*${clip.scale}:-1[${scaledName}]");

      // B. ROTATE
      // 'c=none' makes the background transparent after rotation.
      // 'ow' and 'oh' expand the bounding box so corners aren't cut off.
      // We convert degrees to radians: degree * PI / 180
      _filterChains.add(
        "[$scaledName]rotate=${clip.rotation}*PI/180:c=none:ow=rotw(${clip.rotation}*PI/180):oh=roth(${clip.rotation}*PI/180)[$rotatedName]",
      );

      // C. POSITION (The Coordinate Fix)
      // FFmpeg 0,0 is Top-Left. Flutter (0,0) is usually Center.
      // Formula: (MainWidth - OverlayWidth)/2 + OffsetX
      // We use 'enable' to show it only at the specific time.
      final xPos = "(main_w-overlay_w)/2+${clip.offsetX}";
      final yPos = "(main_h-overlay_h)/2+${clip.offsetY}";

      _filterChains.add(
        "[$currentVideo][$rotatedName]overlay=$xPos:$yPos:enable='between(t,$startTime,$endTime)':eof_action=pass"
        "[$outputName]",
      );

      currentVideo = outputName;
    }

    // Final map to output
    _filterChains.add("[$currentVideo]copy[final_v]");
  }

  // --- 3. Audio Tracks (The 95% Bug Fix) ---
  void addAudioTracks(List<AudioClip> audioClips) {
    // If no extra audio, we still need to process base_a to match video length
    if (audioClips.isEmpty) {
      if (_hasMainVideo) {
        // Force trim audio to video length to prevent hanging
        _filterChains.add(
          "[base_a]atrim=duration=$_totalVideoDuration[final_a]",
        );
      }
      return;
    }

    String mixInputs = "[base_a]";
    int count = 1;

    for (int i = 0; i < audioClips.length; i++) {
      final clip = audioClips[i];
      final idx = _addInput(clip.filePath);
      final label = "audio$i";

      final double startSec =
          (clip.startTimeInSourceInMicroseconds ?? 0) / 1000000.0;
      final double durationSec = clip.durationInMicroseconds / 1000000.0;
      final endSec = startSec + durationSec;

      // Delay: Add delay to align audio on timeline
      final double delaySec =
          clip.startTimeInTimelineInMicroseconds / 1000000.0;
      final delayMs = (delaySec * 1000).toInt();

      _filterChains.add(
        "[$idx:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,"
        "atrim=start=$startSec:end=$endSec,"
        "asetpts=PTS-STARTPTS,"
        "volume=${clip.volume},"
        "adelay=$delayMs|$delayMs[$label]", // Stereo delay
      );

      mixInputs += "[$label]";
      count++;
    }

    // CRITICAL FIX FOR 95% BUG:
    // 1. duration=longest: prevents cutting off early.
    // 2. dropout_transition: smoother fade.
    // 3. Followed by 'atrim' matching video duration. This ensures FFmpeg knows exactly when to stop.
    _filterChains.add(
      "${mixInputs}amix=inputs=$count:duration=longest:dropout_transition=200,"
      "volume=$count," // normalization roughly
      "atrim=duration=$_totalVideoDuration[final_a]",
    );
  }

  // --- BUILD COMMAND ---

  String build(String outputPath, ExportSettings settings) {
    // Validate input files exist
    for (var input in _inputs) {
      final match = RegExp(r'-i\s+"([^"]+)"').firstMatch(input);
      if (match != null) {
        final path = match.group(1)!;
        if (!File(path).existsSync()) {
          throw Exception("Input file not found: $path");
        }
      }
    }

    final finalFilter = _filterChains.join('; ');

    // HARDWARE ACCELERATION & ENCODING SETTINGS
    String videoCodec;
    String extraFlags;

    if (_isAndroid) {
      // Android Hardware Encoder
      videoCodec = 'h264_mediacodec -b:v 5M';
      extraFlags = '';
    } else if (_isIOS) {
      // iOS Hardware Encoder
      videoCodec = 'h264_videotoolbox -b:v 5M';
      extraFlags = '-allow_sw 1';
    } else {
      // Fallback Software
      videoCodec = 'libx264 -preset ultrafast -crf 28';
      extraFlags = '-tune fastdecode';
    }

    // --- CORRECTION HERE ---
    // We removed "ffmpeg " from the start of the string.
    // The library adds it automatically.
    final mainCmd =
        '-y ${_inputs.join(' ')} '
        '-filter_complex "$finalFilter" '
        '-map "[final_v]" -map "[final_a]" '
        '-c:v $videoCodec '
        '-pix_fmt yuv420p '
        '-movflags +faststart '
        '-c:a aac -b:a 128k -ac 2 -ar 44100 '
        '-max_muxing_queue_size 1024 '
        '-shortest '
        '-vsync 2 '
        '$extraFlags '
        '"$outputPath"';

    print(
      '=== CAPCUT-STYLE FFMPEG COMMAND ===\n$mainCmd\n=================================',
    );

    return mainCmd;
  }

  int _addInput(String path, {bool isImage = false}) {
    final idx = _inputs.length;
    // -thread_queue_size 512 prevents input buffer warnings
    if (isImage) {
      _inputs.add(
        '-thread_queue_size 512 -loop 1 -framerate 30 -t 300 -i "$path"',
        // Added -t 300 (5 mins cap) for images to prevent infinite loops if trim fails
      );
    } else {
      _inputs.add('-thread_queue_size 512 -i "$path"');
    }
    return idx;
  }
}
