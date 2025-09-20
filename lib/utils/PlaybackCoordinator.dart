import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:video_player/video_player.dart';

/// Manages all media players and synchronizes playback.
/// This class is designed to be owned by the UI State and be separate
/// from the BLoC to handle high-frequency state changes (playhead position)
/// without causing unnecessary rebuilds of the entire UI.
class PlaybackCoordinator extends ChangeNotifier {
  // --- Public Notifiers for UI consumption ---

  /// Notifies listeners of the current global playhead position.
  /// UI widgets that need to update frequently (like the timeline) should listen to this.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  /// Notifies listeners of the current playback state (playing or paused).
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  /// Notifies listeners of the currently active video controller.
  /// The main VideoViewport widget listens to this to know what to display.
  final ValueNotifier<VideoPlayerController?> activeController = ValueNotifier(
    null,
  );

  // --- Internal State ---
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, AudioPlayer> _audioPlayers = {};
  StreamSubscription<void>? _positionSubscription;
  int _currentClipIndex = 0;

  List<VideoClip> _currentClips = [];
  List<AudioClip> _currentAudioClips = [];
  bool _isDisposed = false;

  /// Main entry point for the UI to update the coordinator's state.
  /// This is called from the BlocListener in EditorView whenever the project data changes.
  Future<void> updateTimeline(
    List<VideoClip> clips,
    List<AudioClip> audioClips,
  ) async {
    if (_isDisposed) return;

    // Pause before making any structural changes to the timeline
    pause();

    _currentClips = List.from(clips);
    _currentAudioClips = List.from(audioClips);

    // Intelligently update player instances
    await _updateVideoControllers(clips);
    await _updateAudioPlayers(audioClips);

    // Ensure the active clip is correct for the current position
    _updateActiveClipForPosition(position.value, seek: true);
  }

  /// Starts or resumes playback.
  void play() {
    if (activeController.value == null || _currentClips.isEmpty) return;

    final activeClip = _currentClips[_currentClipIndex];
    activeController.value!.setPlaybackSpeed(activeClip.speed);
    activeController.value!.setVolume(activeClip.volume);
    activeController.value!.play();

    isPlaying.value = true;

    _positionSubscription?.cancel();
    _positionSubscription = activeController.value!.position.asStream().listen((
      currentPosition,
    ) {
      if (_isDisposed || currentPosition == null) return;

      // --- The "Conductor" Logic ---
      final activeClip = _currentClips[_currentClipIndex];
      Duration globalPosition = Duration.zero;
      for (int i = 0; i < _currentClipIndex; i++) {
        globalPosition += _currentClips[i].duration;
      }
      final timeInClip = (currentPosition - activeClip.startTimeInSource);
      globalPosition += Duration(
        microseconds: (timeInClip.inMicroseconds / activeClip.speed).round(),
      );

      // Notify UI of the new global position
      position.value = globalPosition;

      // Sync all audio players
      for (final audioClip in _currentAudioClips) {
        final player = _audioPlayers[audioClip.uniqueId];
        if (player == null) continue;

        final clipStart = audioClip.startTimeInTimeline;
        final clipEnd = clipStart + audioClip.duration;
        final isWithinBounds =
            globalPosition >= clipStart && globalPosition < clipEnd;

        if (isWithinBounds && !player.playing) {
          player.setVolume(audioClip.volume);
          player.seek(globalPosition - clipStart);
          player.play();
        } else if (!isWithinBounds && player.playing) {
          player.pause();
        }
      }

      // Handle transitioning to the next video clip
      if (currentPosition >= activeClip.endTimeInSource) {
        final nextClipIndex = _currentClipIndex + 1;
        if (nextClipIndex < _currentClips.length) {
          _setActiveClip(nextClipIndex, seekToStart: true);
          play(); // Recursively call play for the next clip
        } else {
          pause();
          _setActiveClip(0, seekToStart: true); // Go back to start
        }
      }
    });
  }

  /// Pauses playback.
  void pause() {
    activeController.value?.pause();
    for (var player in _audioPlayers.values) {
      player.pause();
    }
    _positionSubscription?.cancel();
    isPlaying.value = false;
  }

  /// Seeks the entire timeline to a new position.
  void seek(Duration newPosition) {
    pause(); // Always pause before seeking
    position.value = newPosition;
    _updateActiveClipForPosition(newPosition, seek: true);

    // Correctly seek or stop audio players when scrubbing
    for (final audioClip in _currentAudioClips) {
      final player = _audioPlayers[audioClip.uniqueId];
      if (player == null) continue;

      final seekPositionInAudio = newPosition - audioClip.startTimeInTimeline;

      if (seekPositionInAudio >= Duration.zero &&
          seekPositionInAudio < audioClip.duration) {
        player.seek(seekPositionInAudio);
      } else {
        player.pause();
        player.seek(Duration.zero);
      }
    }
  }

  /// Disposes all player controllers and resources.
  @override
  void dispose() {
    if (_isDisposed) return;
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

  // --- Private Helper Methods (Moved directly from EditorViewState) ---

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
    final newClipIds = audioClips.map((c) => c.uniqueId).toSet();
    final oldClipIds = _audioPlayers.keys.toSet();

    final clipsToRemove = oldClipIds.difference(newClipIds);
    for (final clipId in clipsToRemove) {
      await _audioPlayers[clipId]?.dispose();
      _audioPlayers.remove(clipId);
    }

    for (final clip in audioClips) {
      if (!_audioPlayers.containsKey(clip.uniqueId)) {
        final player = AudioPlayer();
        try {
          await player.setFilePath(clip.filePath);
          _audioPlayers[clip.uniqueId] = player;
        } catch (e) {
          print("Error setting up audio player for ${clip.filePath}: $e");
          player.dispose();
        }
      }
    }
  }

  void _setActiveClip(int index, {bool seekToStart = false}) {
    if (_isDisposed || index >= _currentClips.length || _currentClips.isEmpty) {
      if (activeController.value != null) {
        activeController.value = null;
      }
      return;
    }

    final clip = _currentClips[index];
    final controller = _videoControllers[clip.playablePath];

    if (controller != null && controller.value.isInitialized) {
      controller.setPlaybackSpeed(clip.speed);
      controller.setVolume(clip.volume);
    }

    if (controller != activeController.value) {
      activeController.value = controller;
    }

    if (seekToStart && activeController.value != null) {
      activeController.value!.seekTo(clip.startTimeInSource);
    }
    _currentClipIndex = index;
  }

  void _updateActiveClipForPosition(
    Duration globalPosition, {
    bool seek = false,
  }) {
    if (_currentClips.isEmpty) return;
    Duration cumulativeDuration = Duration.zero;
    for (int i = 0; i < _currentClips.length; i++) {
      final clip = _currentClips[i];
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
    _setActiveClip(_currentClips.length - 1, seekToStart: false);
    activeController.value?.seekTo(_currentClips.last.endTimeInSource);
  }

  // This is used for live previewing the trim handles.
  void seekToClipEdge({
    required int clipIndex,
    required Duration positionInSource,
  }) {
    if (_isDisposed || clipIndex >= _currentClips.length) return;

    pause(); // Ensure we are paused for the preview

    final clip = _currentClips[clipIndex];
    final controller = _videoControllers[clip.playablePath];

    // If the controller for the clip being trimmed isn't the active one, switch it.
    if (controller != null && activeController.value != controller) {
      activeController.value = controller;
    }

    // Seek the controller to the exact frame.
    activeController.value?.seekTo(positionInSource);
  }
}
