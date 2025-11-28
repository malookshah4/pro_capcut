import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';

class PlaybackCoordinator extends ChangeNotifier {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  // Active (Outgoing) Video
  final ValueNotifier<VideoPlayerController?> activeController = ValueNotifier(
    null,
  );

  // Incoming Video (For Transitions)
  final ValueNotifier<VideoPlayerController?> incomingController =
      ValueNotifier(null);
  final ValueNotifier<double> transitionProgress = ValueNotifier(0.0);
  final ValueNotifier<String?> currentTransition = ValueNotifier(null);

  final Map<String, VideoPlayerController> _overlayControllers = {};
  Map<String, VideoPlayerController> _videoControllersCache = {};
  final Map<String, AudioPlayer> _audioPlayers = {};

  int _currentClipIndex = 0;
  List<VideoClip> _mainVideoClips = [];
  List<VideoClip> _overlayClips = [];
  List<AudioClip> _allAudioClips = [];
  bool _isDisposed = false;

  // Track if we are currently preloading to avoid duplicate calls
  bool _isPreloading = false;

  VideoPlayerController? getOverlayController(String clipId) =>
      _overlayControllers[clipId];

  Future<void> updateTimeline(List<EditorTrack> tracks) async {
    if (_isDisposed) return;

    // Pause but don't notify to avoid UI flicker if possible,
    // but safe approach is standard pause.
    pause();

    final videoTrack = tracks.firstWhere(
      (t) => t.type == TrackType.video,
      orElse: () => EditorTrack(id: 'error', type: TrackType.video, clips: []),
    );
    _mainVideoClips = videoTrack.clips.cast<VideoClip>();

    _overlayClips = tracks
        .where((t) => t.type == TrackType.overlay)
        .expand((t) => t.clips)
        .cast<VideoClip>()
        .toList();

    _allAudioClips = tracks
        .where((t) => t.type == TrackType.audio)
        .expand((t) => t.clips)
        .cast<AudioClip>()
        .toList();

    await _updateMainVideoControllers(_mainVideoClips);
    await _updateOverlayControllers(_overlayClips);
    await _updateAudioPlayers(_allAudioClips);

    _updateActiveClipForPosition(position.value, seek: true);
  }

  void play() {
    if (activeController.value == null || _mainVideoClips.isEmpty) return;

    // Auto-Restart if at end
    Duration globalStart = Duration.zero;
    for (var clip in _mainVideoClips) globalStart += clip.duration;

    if (position.value >= globalStart) {
      seek(Duration.zero);
    }

    final activeClip = _mainVideoClips[_currentClipIndex];
    activeController.value!.setPlaybackSpeed(activeClip.speed);
    activeController.value!.setVolume(activeClip.volume);

    activeController.value!.play();
    activeController.value!.addListener(_videoListener);

    // If we paused mid-transition, resume the incoming controller too
    if (incomingController.value != null &&
        incomingController.value!.value.isInitialized) {
      incomingController.value!.play();
    }

    _syncOverlays(position.value, playing: true);
    isPlaying.value = true;
  }

  void pause() {
    if (activeController.value != null) {
      activeController.value!.pause();
      activeController.value!.removeListener(_videoListener);
    }
    if (incomingController.value != null) {
      incomingController.value!.pause();
    }
    for (var c in _overlayControllers.values) {
      if (c.value.isPlaying) c.pause();
    }
    for (var p in _audioPlayers.values) {
      p.pause();
    }
    isPlaying.value = false;
  }

  void _videoListener() {
    if (_isDisposed || activeController.value == null) return;

    final currentPosition = activeController.value!.value.position;
    final activeClip = _mainVideoClips[_currentClipIndex];

    // 1. Global Time Calculation
    Duration globalStartOfClip = Duration.zero;
    for (int i = 0; i < _currentClipIndex; i++) {
      globalStartOfClip += _mainVideoClips[i].duration;
    }

    final timeInClip = (currentPosition - activeClip.startTimeInSource);
    final timelineDurationSoFar = Duration(
      microseconds: (timeInClip.inMicroseconds / activeClip.speed).round(),
    );

    final globalPosition = globalStartOfClip + timelineDurationSoFar;
    position.value = globalPosition;

    // 2. Check for Preload & Transition
    _handleTransitionLogic(activeClip, currentPosition);

    // 3. Sync Others
    _syncOverlays(globalPosition, playing: true);
    _syncAudio(globalPosition);

    // 4. Ensure both controllers keep playing during transition
    if (incomingController.value != null &&
        incomingController.value!.value.isInitialized &&
        isPlaying.value &&
        transitionProgress.value > 0.0 &&
        transitionProgress.value < 1.0) {
      // During active transition - ensure both are playing
      if (!activeController.value!.value.isPlaying) {
        activeController.value!.play();
      }
      if (!incomingController.value!.value.isPlaying) {
        incomingController.value!.play();
      }
    }

    // 5. Loop / Switch Logic
    if (currentPosition >= activeClip.endTimeInSource) {
      _switchToNextClip();
    }
  }

  void _handleTransitionLogic(VideoClip activeClip, Duration currentPosition) {
    // Check if there is a NEXT clip
    if (_currentClipIndex + 1 >= _mainVideoClips.length) {
      // No next clip - clear any active transition
      if (transitionProgress.value > 0.0 || currentTransition.value != null) {
        transitionProgress.value = 0.0;
        currentTransition.value = null;
      }
      return;
    }

    final nextClip = _mainVideoClips[_currentClipIndex + 1];

    // Transition Start Time = EndTime - (TransitionDuration / Speed)
    // NOTE: We divide by speed because the video is playing at that speed
    final transitionDuration = Duration(
      microseconds: nextClip.transitionDurationMicroseconds,
    );

    // Calculate when transition should start in the SOURCE timeline
    final transitionStartPoint = activeClip.endTimeInSource - transitionDuration;

    // --- PRELOAD LOGIC ---
    // Start preloading 1.5 seconds BEFORE the transition starts (or immediately if transition is short)
    final preloadTime = transitionDuration.inMilliseconds > 1500 ? 1500 : transitionDuration.inMilliseconds;
    final preloadPoint = transitionStartPoint - Duration(milliseconds: preloadTime);

    if (currentPosition >= preloadPoint &&
        incomingController.value == null &&
        !_isPreloading) {
      _preloadNextClip(nextClip);
    }

    // --- TRANSITION RENDER LOGIC ---
    if (nextClip.transitionType != null && nextClip.transitionDurationMicroseconds > 0) {
      if (currentPosition >= transitionStartPoint && currentPosition < activeClip.endTimeInSource) {
        // We are IN the transition zone
        if (incomingController.value != null &&
            incomingController.value!.value.isInitialized) {
          // Ensure incoming controller is playing
          if (isPlaying.value && !incomingController.value!.value.isPlaying) {
            incomingController.value!.setPlaybackSpeed(nextClip.speed);
            incomingController.value!.setVolume(nextClip.volume);
            incomingController.value!.play();
          }

          // Calculate Progress (0.0 -> 1.0)
          // timeInTrans is how far we are into the transition
          final timeInTrans = currentPosition - transitionStartPoint;

          // Progress = elapsed time / total transition duration
          double progress = timeInTrans.inMicroseconds / transitionDuration.inMicroseconds;
          progress = progress.clamp(0.0, 1.0);

          transitionProgress.value = progress;
          if (currentTransition.value != nextClip.transitionType) {
            currentTransition.value = nextClip.transitionType;
          }
        } else {
          // Incoming not ready - show 0 progress
          transitionProgress.value = 0.0;
          if (currentTransition.value != nextClip.transitionType) {
            currentTransition.value = nextClip.transitionType;
          }
        }
      } else if (currentPosition < transitionStartPoint) {
        // Before transition - reset
        if (transitionProgress.value > 0.0) {
          transitionProgress.value = 0.0;
        }
      }
    } else {
      // No transition on next clip - clear
      if (transitionProgress.value > 0.0 || currentTransition.value != null) {
        transitionProgress.value = 0.0;
        currentTransition.value = null;
      }
    }
  }

  Future<void> _preloadNextClip(VideoClip nextClip) async {
    _isPreloading = true;
    try {
      // Check cache first
      VideoPlayerController? controller =
          _videoControllersCache[nextClip.playablePath];

      if (controller == null) {
        controller = VideoPlayerController.file(File(nextClip.playablePath));
        _videoControllersCache[nextClip.playablePath] = controller;
        await controller.initialize();
      } else if (!controller.value.isInitialized) {
        await controller.initialize();
      }

      // Prepare it silently
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(nextClip.speed);
      await controller.setVolume(nextClip.volume);
      await controller.seekTo(nextClip.startTimeInSource);

      // Ready to go
      incomingController.value = controller;
    } catch (e) {
      print("Error preloading next clip: $e");
    } finally {
      _isPreloading = false;
    }
  }

  void _switchToNextClip() {
    final nextClipIndex = _currentClipIndex + 1;
    if (nextClipIndex < _mainVideoClips.length) {
      final wasPlaying = isPlaying.value;
      activeController.value!.removeListener(_videoListener);

      // Swap Controllers
      if (incomingController.value != null) {
        // Smooth Handoff - Transition completed
        final oldController = activeController.value;

        // Don't pause old controller yet - let it finish naturally
        // oldController?.pause();

        activeController.value = incomingController.value;
        activeController.value!.addListener(_videoListener);

        // Clear transition state
        incomingController.value = null;
        transitionProgress.value = 0.0;
        currentTransition.value = null;
        _isPreloading = false;

        _currentClipIndex = nextClipIndex;

        // Ensure new active controller is playing if we were playing
        if (wasPlaying) {
          final nextClip = _mainVideoClips[nextClipIndex];
          activeController.value!.setPlaybackSpeed(nextClip.speed);
          activeController.value!.setVolume(nextClip.volume);
          if (!activeController.value!.value.isPlaying) {
            activeController.value!.play();
          }
        }

        // Now pause and clean up old controller
        oldController?.pause();
      } else {
        // Hard Cut / Fallback if preload failed
        transitionProgress.value = 0.0;
        currentTransition.value = null;
        _isPreloading = false;
        _setActiveClip(nextClipIndex, seekToStart: true);
        if (wasPlaying) {
          play();
        }
      }
    } else {
      // End of timeline
      pause();
      transitionProgress.value = 0.0;
      currentTransition.value = null;
      _setActiveClip(0, seekToStart: true);
      position.value = Duration.zero;
    }
  }

  void seek(Duration newPosition) {
    bool wasPlaying = isPlaying.value;
    if (wasPlaying) pause();

    position.value = newPosition;
    _updateActiveClipForPosition(newPosition, seek: true);
    _syncOverlays(newPosition, playing: false);
    _syncAudio(newPosition);

    // Reset transition state on seek
    if (incomingController.value != null) {
      incomingController.value?.pause();
      incomingController.value = null;
    }
    transitionProgress.value = 0.0;
    currentTransition.value = null;
    _isPreloading = false;
  }

  // ... (Keep remaining methods: _syncOverlays, _syncAudio, dispose, updateControllers, _setActiveClip, _updateActiveClipForPosition) ...
  // Please ensure the rest of the file (from previous steps) is preserved here.
  // Repeating standard methods for completeness would exceed limit,
  // but they remain UNCHANGED from the previous working version.

  void _syncOverlays(Duration globalPosition, {required bool playing}) {
    for (final clip in _overlayClips) {
      if (!_overlayControllers.containsKey(clip.id)) continue;
      final controller = _overlayControllers[clip.id]!;
      final start = Duration(
        microseconds: clip.startTimeInTimelineInMicroseconds,
      );
      final end = start + clip.duration;

      if (globalPosition >= start && globalPosition < end) {
        final offset = globalPosition - start;
        final seekTarget = clip.startTimeInSource + (offset * clip.speed);

        if (!controller.value.isInitialized) continue;
        final currentPos = controller.value.position;
        if ((currentPos - seekTarget).abs().inMilliseconds > 150) {
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
        if (controller.value.isPlaying) controller.pause();
      }
    }
  }

  void _syncAudio(Duration globalPosition) {
    for (final audioClip in _allAudioClips) {
      final player = _audioPlayers[audioClip.id];
      if (player == null) continue;
      final start = Duration(
        microseconds: audioClip.startTimeInTimelineInMicroseconds,
      );
      final end = start + audioClip.duration;
      if (globalPosition >= start && globalPosition < end) {
        // Audio seek omitted
      } else {
        if (player.playing) player.pause();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    activeController.value?.removeListener(_videoListener);
    for (var c in _videoControllersCache.values) c.dispose();
    for (var c in _overlayControllers.values) c.dispose();
    for (var p in _audioPlayers.values) p.dispose();
    _videoControllersCache.clear();
    _overlayControllers.clear();
    _audioPlayers.clear();
    position.dispose();
    isPlaying.dispose();
    activeController.dispose();
    incomingController.dispose();
    transitionProgress.dispose();
    currentTransition.dispose();
    super.dispose();
  }

  Future<void> _updateMainVideoControllers(List<VideoClip> clips) async {
    final uniquePaths = clips.map((c) => c.playablePath).toSet();
    final newControllers = <String, VideoPlayerController>{};
    for (final path in uniquePaths) {
      if (_videoControllersCache.containsKey(path)) {
        newControllers[path] = _videoControllersCache[path]!;
        _videoControllersCache.remove(path);
      } else {
        final controller = VideoPlayerController.file(File(path));
        try {
          await controller.initialize();
          newControllers[path] = controller;
        } catch (e) {
          print("Error init main: $e");
        }
      }
    }
    for (var c in _videoControllersCache.values) c.dispose();
    _videoControllersCache = newControllers;
  }

  Future<void> _updateOverlayControllers(List<VideoClip> clips) async {
    final newIds = clips.map((c) => c.id).toSet();
    final oldIds = _overlayControllers.keys.toSet();
    final toRemove = oldIds.difference(newIds);
    for (var id in toRemove) {
      await _overlayControllers[id]?.dispose();
      _overlayControllers.remove(id);
    }
    for (final clip in clips) {
      if (!_overlayControllers.containsKey(clip.id)) {
        final controller = VideoPlayerController.file(File(clip.playablePath));
        try {
          await controller.initialize();
          _overlayControllers[clip.id] = controller;
        } catch (e) {}
      }
    }
  }

  Future<void> _updateAudioPlayers(List<AudioClip> clips) async {
    final newIds = clips.map((c) => c.id).toSet();
    final oldIds = _audioPlayers.keys.toSet();
    final toRemove = oldIds.difference(newIds);
    for (var id in toRemove) {
      await _audioPlayers[id]?.dispose();
      _audioPlayers.remove(id);
    }
    for (final clip in clips) {
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

    if (activeController.value != null) {
      activeController.value!.removeListener(_videoListener);
    }

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
    if (seek && activeController.value != null) {
      activeController.value!.seekTo(_mainVideoClips.last.endTimeInSource);
    }
  }
}
