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
  final ValueNotifier<VideoPlayerController?> activeController = ValueNotifier(
    null,
  );

  Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, AudioPlayer> _audioPlayers = {};
  StreamSubscription<void>? _positionSubscription;
  int _currentClipIndex = 0;

  List<VideoClip> _mainVideoClips = [];
  List<AudioClip> _allAudioClips = [];
  bool _isDisposed = false;

  Future<void> updateTimeline(List<EditorTrack> tracks) async {
    if (_isDisposed) return;
    pause();

    final videoTrack = tracks.firstWhere(
      (t) => t.type == TrackType.video,
      orElse: () => EditorTrack(id: 'error', type: TrackType.video, clips: []),
    );
    _mainVideoClips = videoTrack.clips.cast<VideoClip>();

    _allAudioClips = tracks
        .where((t) => t.type == TrackType.audio)
        .expand((t) => t.clips)
        .cast<AudioClip>()
        .toList();

    await _updateVideoControllers(_mainVideoClips);
    await _updateAudioPlayers(_allAudioClips);

    _updateActiveClipForPosition(position.value, seek: true);
  }

  void play() {
    if (activeController.value == null || _mainVideoClips.isEmpty) return;

    final activeClip = _mainVideoClips[_currentClipIndex];
    activeController.value!.setPlaybackSpeed(activeClip.speed);
    activeController.value!.setVolume(activeClip.volume);
    activeController.value!.play();

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

      position.value = globalPosition;

      // --- SYNC AUDIO PLAYERS ---
      for (final audioClip in _allAudioClips) {
        final player = _audioPlayers[audioClip.id];
        if (player == null) continue;

        final clipStart = audioClip.startTime;
        final clipEnd = clipStart + audioClip.duration;
        final isWithinBounds =
            globalPosition >= clipStart && globalPosition < clipEnd;

        if (isWithinBounds) {
          // CORRECT MATH: Where are we inside the clip?
          final offsetInClip = globalPosition - clipStart;
          // CORRECT MATH: Add the source offset (e.g. if clip starts at 00:10 of the song)
          final seekTarget = audioClip.startTimeInSource + offsetInClip;

          if (!player.playing) {
            player.setVolume(audioClip.volume);
            player.seek(seekTarget);
            player.play();
          }
        } else {
          if (player.playing) {
            player.pause();
          }
        }
      }

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

  void pause() {
    activeController.value?.pause();
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

    for (final audioClip in _allAudioClips) {
      final player = _audioPlayers[audioClip.id];
      if (player == null) continue;

      if (newPosition >= audioClip.startTime &&
          newPosition < audioClip.endTime) {
        // Correct seek logic
        final offsetInClip = newPosition - audioClip.startTime;
        final seekTarget = audioClip.startTimeInSource + offsetInClip;
        player.seek(seekTarget);
      } else {
        player.pause();
        player.seek(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    _videoControllers.clear();
    _audioPlayers.clear();
    position.dispose();
    isPlaying.dispose();
    activeController.dispose();
    super.dispose();
  }

  Future<void> _updateVideoControllers(List<VideoClip> clips) async {
    final uniquePaths = clips.map((c) => c.playablePath).toSet();
    final newControllers = <String, VideoPlayerController>{};
    final oldControllers = Map.of(_videoControllers);

    for (final path in uniquePaths) {
      if (oldControllers.containsKey(path)) {
        newControllers[path] = oldControllers.remove(path)!;
      } else {
        final controller = VideoPlayerController.file(File(path));
        try {
          await controller.initialize();
          newControllers[path] = controller;
        } catch (e) {
          print("Error initializing controller for $path: $e");
          controller.dispose();
        }
      }
    }
    for (var controller in oldControllers.values) {
      controller.dispose();
    }
    if (!_isDisposed) {
      _videoControllers = newControllers;
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
          print("Error setting up audio player for ${clip.filePath}: $e");
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
    final controller = _videoControllers[clip.playablePath];
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
