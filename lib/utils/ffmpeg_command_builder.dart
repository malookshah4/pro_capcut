import 'dart:io';
import 'dart:math'; // Import math for floor/round
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';

class FFmpegCommandBuilder {
  final List<String> _inputs = [];
  final List<String> _filterChains = [];
  int _streamCount = 0;
  bool _hasMainVideo = false;
  double _totalVideoDuration = 0.0;

  bool get _isAndroid => Platform.isAndroid;
  bool get _isIOS => Platform.isIOS;

  // --- Helper: Snap time to 30 FPS grid ---
  // This ensures our Dart math matches FFmpeg's 'fps=30' filter exactly.
  double _quantizeToFrames(double seconds) {
    // Floor ensures we never overestimate duration (which causes black frames/skipped transitions)
    return (seconds * 30.0).floor() / 30.0;
  }

  // --- 1. Main Video (Robust XFADE Chain) ---
  void setMainVideo(List<VideoClip> clips, Map<String, bool> hasAudioMap) {
    if (clips.isEmpty) {
      _filterChains.add("color=s=1080x1920:d=5[c_v];anullsrc[c_a]");
      _hasMainVideo = true;
      return;
    }

    List<String> vStreams = [];
    List<String> aStreams = [];
    List<double> clipDurations = []; // Store quantized durations

    // A. PREPARE STREAMS
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final idx = _addInput(clip.sourcePath);

      final double rawDuration =
          (clip.endTimeInSourceInMicroseconds -
              clip.startTimeInSourceInMicroseconds) /
          1000000.0;
      // IMPORTANT: Account for speed when calculating time length
      final double realDuration = rawDuration / clip.speed;

      // Quantize: Round DOWN to nearest frame so we don't overshoot
      final double quantizedDuration = _quantizeToFrames(realDuration);
      clipDurations.add(quantizedDuration);

      final startSec = (clip.startTimeInSourceInMicroseconds / 1000000.0)
          .toStringAsFixed(3);
      final endSec = (clip.endTimeInSourceInMicroseconds / 1000000.0)
          .toStringAsFixed(3);
      final ptsMult = (1.0 / clip.speed).toStringAsFixed(4);

      final vLabel = "v_in_$i";
      final aLabel = "a_in_$i";

      // FORCE fps=30 and settb=1/30 so timestamps align perfectly with our math
      _filterChains.add(
        "[$idx:v]trim=start=$startSec:end=$endSec,setpts=$ptsMult*(PTS-STARTPTS),"
        "scale=1080:1920:force_original_aspect_ratio=decrease:flags=bicubic,"
        "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,setsar=1,"
        "fps=30,settb=1/30,format=yuv420p[$vLabel]",
      );
      vStreams.add("[$vLabel]");

      if (hasAudioMap[clip.sourcePath] == true) {
        _filterChains.add(
          "[$idx:a]atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS,"
          "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,"
          "volume=${clip.volume}[$aLabel]",
        );
      } else {
        _filterChains.add(
          "anullsrc=r=44100:cl=stereo:d=$quantizedDuration[$aLabel]",
        );
      }
      aStreams.add("[$aLabel]");
    }

    // B. CHAIN STREAMS
    String currentV = vStreams[0];
    String currentA = aStreams[0];
    double currentOffset =
        clipDurations[0]; // Start offset at end of first clip

    for (int i = 1; i < clips.length; i++) {
      final clip = clips[i];
      final nextV = vStreams[i];
      final nextA = aStreams[i];

      final String nextVLabel = "v_mix_$i";
      final String nextALabel = "a_mix_$i";

      // Transition Logic
      String transType = "fade";
      double transDur = 0.0;

      if (clip.transitionType != null) {
        transType = clip.transitionType!;
        transDur = clip.transitionDurationMicroseconds / 1000000.0;
      }

      // Quantize transition duration too (safer)
      transDur = _quantizeToFrames(transDur);

      if (transDur > 0) {
        // Check: Ensure transition fits within previous clip
        // (This prevents "start time > input duration" errors)
        // We subtract a tiny epsilon (0.001) to be safe
        if (transDur > currentOffset) transDur = currentOffset - 0.03;

        final double offset = currentOffset - transDur;
        final String offsetStr = offset.toStringAsFixed(3);
        final String durStr = transDur.toStringAsFixed(3);

        _filterChains.add(
          "$currentV${nextV}xfade=transition=$transType:duration=$durStr:offset=$offsetStr[$nextVLabel]",
        );

        // Update accumulator:
        // New End = (Old End) - (Overlap) + (Next Clip Length)
        currentOffset = (currentOffset - transDur) + clipDurations[i];

        // Audio
        _filterChains.add("$currentA${nextA}acrossfade=d=$durStr[$nextALabel]");
      } else {
        // Hard Cut (Concat)
        _filterChains.add("$currentV${nextV}concat=n=2:v=1:a=0[$nextVLabel]");
        _filterChains.add("$currentA${nextA}concat=n=2:v=0:a=1[$nextALabel]");

        currentOffset += clipDurations[i];
      }

      currentV = "[$nextVLabel]";
      currentA = "[$nextALabel]";
    }

    // Final Map
    _filterChains.add("${currentV}copy[base_v]");
    _filterChains.add("${currentA}acopy[base_a]");

    _hasMainVideo = true;
    _totalVideoDuration = currentOffset;
  }

  // --- 2. Overlays (Fixed Timestamp) ---
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
      final idx = _addInput(clip.sourcePath, isImage: isImage);

      final double timelineStartVal =
          clip.startTimeInTimelineInMicroseconds / 1000000.0;
      final double durationVal =
          (clip.durationInMicroseconds / 1000000.0) / clip.speed;
      final double timelineEndVal = timelineStartVal + durationVal;

      final timelineStart = timelineStartVal.toStringAsFixed(3);
      final timelineEnd = timelineEndVal.toStringAsFixed(3);

      final startSec = (clip.startTimeInSourceInMicroseconds / 1000000.0)
          .toStringAsFixed(3);
      final endSec = (clip.endTimeInSourceInMicroseconds / 1000000.0)
          .toStringAsFixed(3);

      final ptsMult = (1.0 / clip.speed).toStringAsFixed(4);

      final trimmedName = "v_trim_$i";
      final scaledName = "v_scaled_$i";
      final rotatedName = "v_rotated_$i";
      final outputName = "v_out_$i";

      final scaleStr = clip.scale.toStringAsFixed(4);
      final rotStr = clip.rotation.toStringAsFixed(4);

      if (!isImage) {
        _filterChains.add(
          "[$idx:v]trim=start=$startSec:end=$endSec,"
          "setpts=$ptsMult*(PTS-STARTPTS)+($timelineStart/TB)[$trimmedName]",
        );
      } else {
        _filterChains.add("[$idx:v]format=yuva420p[$trimmedName]");
      }

      // Scale & Rotate
      _filterChains.add(
        "[$trimmedName]scale=ceil(iw*$scaleStr/2)*2:-2,format=yuva420p[${scaledName}]",
      );

      _filterChains.add(
        "[$scaledName]rotate=$rotStr:c=none:ow=rotw($rotStr):oh=roth($rotStr)[$rotatedName]",
      );

      final xPos = "(main_w-overlay_w)/2+${clip.offsetX}";
      final yPos = "(main_h-overlay_h)/2+${clip.offsetY}";

      _filterChains.add(
        "[$currentVideo][$rotatedName]overlay=$xPos:$yPos:enable='between(t,$timelineStart,$timelineEnd)':eof_action=pass"
        "[$outputName]",
      );
      currentVideo = outputName;
    }

    _filterChains.add("[$currentVideo]copy[final_v]");
  }

  // --- 3. Audio Tracks ---
  void addAudioTracks(List<AudioClip> audioClips) {
    if (audioClips.isEmpty) {
      if (_hasMainVideo) {
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

      final startSec = (clip.startTimeInSourceInMicroseconds / 1000000.0)
          .toStringAsFixed(3);
      final double endVal =
          (clip.startTimeInSourceInMicroseconds + clip.durationInMicroseconds) /
          1000000.0;
      final endSec = endVal.toStringAsFixed(3);

      final double delaySec =
          clip.startTimeInTimelineInMicroseconds / 1000000.0;
      final delayMs = (delaySec * 1000).toInt();

      _filterChains.add(
        "[$idx:a]atrim=start=$startSec:end=$endSec,"
        "asetpts=PTS-STARTPTS,"
        "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,"
        "volume=${clip.volume},"
        "adelay=$delayMs|$delayMs[$label]",
      );
      mixInputs += "[$label]";
      count++;
    }

    _filterChains.add(
      "${mixInputs}amix=inputs=$count:duration=longest:dropout_transition=200,"
      "volume=$count,"
      "atrim=duration=$_totalVideoDuration[final_a]",
    );
  }

  String build(String outputPath, ExportSettings settings) {
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

    String videoCodec;
    String extraFlags;

    if (_isAndroid) {
      videoCodec = 'h264_mediacodec -b:v 5M';
      extraFlags = '';
    } else if (_isIOS) {
      videoCodec = 'h264_videotoolbox -b:v 5M';
      extraFlags = '-allow_sw 1';
    } else {
      videoCodec = 'libx264 -preset ultrafast -crf 28';
      extraFlags = '-tune fastdecode';
    }

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
    if (isImage) {
      _inputs.add(
        '-thread_queue_size 512 -loop 1 -framerate 30 -t 300 -i "$path"',
      );
    } else {
      _inputs.add('-thread_queue_size 512 -i "$path"');
    }
    return _inputs.length - 1;
  }
}
