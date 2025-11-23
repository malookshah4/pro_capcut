import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';

class PlaybackCoordinator extends ChangeNotifier {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  // Main Video Controller (The canvas background)
  final ValueNotifier<VideoPlayerController?> activeController = ValueNotifier(
    null,
  );

  // Map of Overlay Video Controllers (PIP)
  // Key: Clip ID, Value: Controller
  final Map<String, VideoPlayerController> _overlayControllers = {};

  Map<String, VideoPlayerController> _videoControllersCache = {};
  final Map<String, AudioPlayer> _audioPlayers = {};
  StreamSubscription<void>? _positionSubscription;
  int _currentClipIndex = 0;

  List<VideoClip> _mainVideoClips = [];
  List<VideoClip> _overlayClips = []; // Active overlays
  List<AudioClip> _allAudioClips = [];
  bool _isDisposed = false;

  // Accessor for Overlay Layers
  VideoPlayerController? getOverlayController(String clipId) =>
      _overlayControllers[clipId];

  Future<void> updateTimeline(List<EditorTrack> tracks) async {
    if (_isDisposed) return;
    pause();

    // 1. Main Video
    final videoTrack = tracks.firstWhere(
      (t) => t.type == TrackType.video,
      orElse: () => EditorTrack(id: 'error', type: TrackType.video, clips: []),
    );
    _mainVideoClips = videoTrack.clips.cast<VideoClip>();

    // 2. Overlays
    _overlayClips = tracks
        .where((t) => t.type == TrackType.overlay)
        .expand((t) => t.clips)
        .cast<VideoClip>()
        .toList();

    // 3. Audio
    _allAudioClips = tracks
        .where((t) => t.type == TrackType.audio)
        .expand((t) => t.clips)
        .cast<AudioClip>()
        .toList();

    await _updateMainVideoControllers(_mainVideoClips);
    await _updateOverlayControllers(_overlayClips); // Init PIPs
    await _updateAudioPlayers(_allAudioClips);

    _updateActiveClipForPosition(position.value, seek: true);
  }

  void play() {
    if (activeController.value == null || _mainVideoClips.isEmpty) return;

    final activeClip = _mainVideoClips[_currentClipIndex];
    activeController.value!.setPlaybackSpeed(activeClip.speed);
    activeController.value!.setVolume(activeClip.volume);
    activeController.value!.play();

    // Start all visible overlays
    _syncOverlays(position.value, playing: true);

    isPlaying.value = true;
    _positionSubscription?.cancel();

    _positionSubscription = activeController.value!.position.asStream().listen((
      currentPosition,
    ) {
      if (_isDisposed || currentPosition == null) return;

      final activeClip = _mainVideoClips[_currentClipIndex];

      Duration globalPosition = Duration.zero;
      for (int i = 0; i < _currentClipIndex; i++) {
        globalPosition += _mainVideoClips[i].duration;
      }

      final timeInClip = (currentPosition - activeClip.startTimeInSource);
      globalPosition += Duration(
        microseconds: (timeInClip.inMicroseconds / activeClip.speed).round(),
      );

      if (!_isDisposed) {
        position.value = globalPosition;
      }

      // Sync Overlays & Audio continuously
      _syncOverlays(globalPosition, playing: true);
      _syncAudio(globalPosition);

      // Loop Main Video Logic
      if (currentPosition >= activeClip.endTimeInSource) {
        final nextClipIndex = _currentClipIndex + 1;
        if (nextClipIndex < _mainVideoClips.length) {
          _setActiveClip(nextClipIndex, seekToStart: true);
          play();
        } else {
          pause();
          _setActiveClip(0, seekToStart: true);
        }
      }
    });
  }

  Future<void> disposePlayerForExport() async {
    try {
      print("Coordinator: Releasing ALL resources for export...");

      // 1. Stop listening to position updates
      _positionSubscription?.cancel();
      _positionSubscription = null;

      // 2. Dispose Main Video Controller
      if (activeController.value != null) {
        await activeController.value!.pause();
        await activeController.value!.dispose();
        activeController.value = null;
      }

      // 3. Dispose ALL Overlay Controllers (Critical for resource release)
      for (var controller in _overlayControllers.values) {
        await controller.pause();
        await controller.dispose();
      }
      _overlayControllers.clear();

      // 4. Dispose ALL Audio Players (Critical for fixing the 95% audio hang)
      for (var player in _audioPlayers.values) {
        await player.stop();
        await player.dispose();
      }
      _audioPlayers.clear();

      // 5. Dispose cached controllers
      for (var controller in _videoControllersCache.values) {
        await controller.dispose();
      }
      _videoControllersCache.clear();

      print("Coordinator: All players disposed. Hardware resources freed.");
    } catch (e) {
      print("Error disposing players for export: $e");
    }
  }

  void pause() {
    activeController.value?.pause();
    // Pause Overlays
    for (var controller in _overlayControllers.values) {
      if (controller.value.isPlaying) controller.pause();
    }
    for (var player in _audioPlayers.values) {
      player.pause();
    }
    _positionSubscription?.cancel();
    isPlaying.value = false;
  }

  void seek(Duration newPosition) {
    pause();
    position.value = newPosition;
    _updateActiveClipForPosition(newPosition, seek: true);
    _syncOverlays(newPosition, playing: false);
    _syncAudio(newPosition);
  }

  void _syncOverlays(Duration globalPosition, {required bool playing}) {
    for (final clip in _overlayClips) {
      if (!_overlayControllers.containsKey(clip.id)) continue;
      final controller = _overlayControllers[clip.id]!;

      if (globalPosition >= clip.startTime && globalPosition < clip.endTime) {
        final offset = globalPosition - clip.startTime;
        final seekTarget = clip.startTimeInSource + offset;

        // If controller is not initialized, ignore
        if (!controller.value.isInitialized) continue;

        // Check if desynced (more than 100ms off)
        final currentPos = controller.value.position;
        if ((currentPos - seekTarget).abs().inMilliseconds > 100) {
          controller.seekTo(seekTarget);
        }

        if (playing && !controller.value.isPlaying) {
          controller.setPlaybackSpeed(clip.speed);
          controller.setVolume(clip.volume);
          controller.play();
        } else if (!playing && controller.value.isPlaying) {
          controller.pause();
        }
      } else {
        if (controller.value.isPlaying) {
          controller.pause();
        }
      }
    }
  }

  void _syncAudio(Duration globalPosition) {
    for (final audioClip in _allAudioClips) {
      final player = _audioPlayers[audioClip.id];
      if (player == null) continue;

      if (globalPosition >= audioClip.startTime &&
          globalPosition < audioClip.endTime) {
        final offsetInClip = globalPosition - audioClip.startTime;
        final seekTarget = audioClip.startTimeInSource + offsetInClip;

        // Audio logic is handled mostly in play(), but seek needs this
        if (!isPlaying.value) {
          // Only seek if paused, otherwise let it play
          // player.seek(seekTarget); // Warning: Frequent seeking causes stutter
        }
      } else {
        if (player.playing) {
          player.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    for (var controller in _videoControllersCache.values) controller.dispose();
    for (var controller in _overlayControllers.values) controller.dispose();
    for (var player in _audioPlayers.values) player.dispose();

    _videoControllersCache.clear();
    _overlayControllers.clear();
    _audioPlayers.clear();

    position.dispose();
    isPlaying.dispose();
    activeController.dispose();
    super.dispose();
  }

  Future<void> _updateMainVideoControllers(List<VideoClip> clips) async {
    final uniquePaths = clips.map((c) => c.playablePath).toSet();
    final newControllers = <String, VideoPlayerController>{};

    for (final path in uniquePaths) {
      if (_videoControllersCache.containsKey(path)) {
        newControllers[path] = _videoControllersCache[path]!;
        _videoControllersCache.remove(path); // Move ownership
      } else {
        final controller = VideoPlayerController.file(File(path));
        try {
          await controller.initialize();
          newControllers[path] = controller;
        } catch (e) {
          print("Error init main controller: $e");
        }
      }
    }

    // Dispose unused
    for (var c in _videoControllersCache.values) c.dispose();
    _videoControllersCache = newControllers;
  }

  Future<void> _updateOverlayControllers(List<VideoClip> clips) async {
    final newIds = clips.map((c) => c.id).toSet();
    final oldIds = _overlayControllers.keys.toSet();

    // Remove deleted
    final toRemove = oldIds.difference(newIds);
    for (var id in toRemove) {
      await _overlayControllers[id]?.dispose();
      _overlayControllers.remove(id);
    }

    // Add new
    for (final clip in clips) {
      if (!_overlayControllers.containsKey(clip.id)) {
        final controller = VideoPlayerController.file(File(clip.playablePath));
        try {
          await controller.initialize();
          _overlayControllers[clip.id] = controller;
        } catch (e) {
          print("Error init overlay controller: $e");
        }
      }
    }
  }

  Future<void> _updateAudioPlayers(List<AudioClip> audioClips) async {
    final newClipIds = audioClips.map((c) => c.id).toSet();
    final oldClipIds = _audioPlayers.keys.toSet();

    final clipsToRemove = oldClipIds.difference(newClipIds);
    for (final clipId in clipsToRemove) {
      await _audioPlayers[clipId]?.dispose();
      _audioPlayers.remove(clipId);
    }

    for (final clip in audioClips) {
      if (!_audioPlayers.containsKey(clip.id)) {
        final player = AudioPlayer();
        try {
          await player.setFilePath(clip.filePath);
          _audioPlayers[clip.id] = player;
        } catch (e) {
          player.dispose();
        }
      }
    }
  }

  void _setActiveClip(int index, {bool seekToStart = false}) {
    if (_isDisposed ||
        index >= _mainVideoClips.length ||
        _mainVideoClips.isEmpty) {
      activeController.value = null;
      return;
    }
    final clip = _mainVideoClips[index];
    final controller = _videoControllersCache[clip.playablePath];
    if (controller != null && controller.value.isInitialized) {
      controller.setPlaybackSpeed(clip.speed);
      controller.setVolume(clip.volume);
    }
    activeController.value = controller;

    if (seekToStart && activeController.value != null) {
      activeController.value!.seekTo(clip.startTimeInSource);
    }
    _currentClipIndex = index;
  }

  void _updateActiveClipForPosition(
    Duration globalPosition, {
    bool seek = false,
  }) {
    if (_mainVideoClips.isEmpty) return;
    Duration cumulativeDuration = Duration.zero;
    for (int i = 0; i < _mainVideoClips.length; i++) {
      final clip = _mainVideoClips[i];
      final clipEnd = cumulativeDuration + clip.duration;
      if (globalPosition >= cumulativeDuration && globalPosition < clipEnd) {
        if (_currentClipIndex != i || activeController.value == null) {
          _setActiveClip(i);
        }
        if (seek && activeController.value != null) {
          final timeIntoClip = globalPosition - cumulativeDuration;
          final seekPosInSource =
              clip.startTimeInSource +
              Duration(
                microseconds: (timeIntoClip.inMicroseconds * clip.speed)
                    .round(),
              );
          activeController.value!.seekTo(seekPosInSource);
        }
        return;
      }
      cumulativeDuration = clipEnd;
    }
    _setActiveClip(_mainVideoClips.length - 1, seekToStart: false);
    activeController.value?.seekTo(_mainVideoClips.last.endTimeInSource);
  }
}
