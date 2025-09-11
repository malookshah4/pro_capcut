// lib/presentation/screens/editor_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/_video_viewport.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/exporting_screen.dart';
import 'package:pro_capcut/presentation/widgets/timeline_area.dart';
import 'package:pro_capcut/utils/thumbnail_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class EditorScreen extends StatelessWidget {
  final Project project;
  const EditorScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditorBloc()..add(EditorProjectLoaded(project)),
      child: EditorView(project: project),
    );
  }
}

class EditorView extends StatefulWidget {
  final Project project;
  const EditorView({super.key, required this.project});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  Map<String, VideoPlayerController> _controllers = {};
  VideoPlayerController? _activeController;
  Map<String, AudioPlayer> _audioPlayers = {};

  int _currentClipIndex = 0;
  StreamSubscription<void>? _positionSubscription; // Changed to void
  EditorLoaded? _latestLoadedState;

  List<VideoClip> _lastKnownClips = [];
  List<AudioClip> _lastKnownAudioClips = [];

  bool _wasPlayingBeforeDrag = false;
  EditorToolbar _currentToolbar = EditorToolbar.main;
  int _selectedToolIndex = 0;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _controllers.values.forEach((controller) => controller.dispose());
    _audioPlayers.values.forEach((player) => player.dispose());
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_latestLoadedState != null) {
      final currentState = _latestLoadedState!;
      String? newThumbnailPath;

      // ✨ FIX: Thumbnail regeneration logic
      if (currentState.currentClips.isNotEmpty) {
        final firstClipPath = currentState.currentClips.first.sourcePath;

        // 1. Delete the old thumbnail to prevent cluttering the cache.
        await ThumbnailUtils.deleteThumbnail(widget.project.thumbnailPath);

        // 2. Generate a new one from the current first clip.
        newThumbnailPath = await ThumbnailUtils.generateAndSaveThumbnail(
          firstClipPath,
          currentState.projectId,
        );
      } else {
        // If there are no clips left, just delete the old thumbnail.
        await ThumbnailUtils.deleteThumbnail(widget.project.thumbnailPath);
        newThumbnailPath = null;
      }

      final updatedProject = Project(
        id: currentState.projectId,
        lastModified: DateTime.now(),
        videoClips: currentState.currentClips,
        audioClips: currentState.audioClips,
        // 3. Save the project with the new thumbnail path.
        thumbnailPath: newThumbnailPath,
      );

      final projectsBox = Hive.box<Project>('projects');
      await projectsBox.put(updatedProject.id, updatedProject);

      if (mounted) {
        Fluttertoast.showToast(msg: "Project Saved");
      }
    }
    return true;
  }

  Future<void> _updateAudioPlayers(List<AudioClip> audioClips) async {
    if (!mounted) return;

    final newClipIds = audioClips.map((c) => c.uniqueId).toSet();
    final oldClipIds = _audioPlayers.keys.toSet();

    // Remove players for clips that no longer exist
    final clipsToRemove = oldClipIds.difference(newClipIds);
    for (final clipId in clipsToRemove) {
      await _audioPlayers[clipId]?.dispose();
      _audioPlayers.remove(clipId);
    }

    // Add players for new clips
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
    _lastKnownAudioClips = List.from(audioClips);
  }

  void _onClipsChanged(List<VideoClip> newClips) {
    if (!listEquals(_lastKnownClips, newClips)) {
      _lastKnownClips = List.from(newClips);
      _updateControllers(newClips);
    }
  }

  Future<void> _updateControllers(List<VideoClip> clips) async {
    if (!mounted) return;

    final uniquePaths = clips.map((c) => c.playablePath).toSet();
    final newControllers = <String, VideoPlayerController>{};
    final oldControllers = Map.of(_controllers);

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

    if (mounted) {
      setState(() {
        _controllers = newControllers;
      });
      final currentPosition =
          (context.read<EditorBloc>().state as EditorLoaded).videoPosition;
      _updateActiveClipForPosition(currentPosition, clips, seek: true);
    }
  }

  void _setActiveClip(
    int index,
    List<VideoClip> clips, {
    bool seekToStart = false,
  }) {
    if (!mounted || index >= clips.length || clips.isEmpty) {
      if (_activeController != null) {
        setState(() => _activeController = null);
      }
      return;
    }

    final clip = clips[index];
    final controller = _controllers[clip.playablePath];

    if (controller != null && controller.value.isInitialized) {
      controller.setPlaybackSpeed(clip.speed);
      controller.setVolume(clip.volume);
    }

    if (controller != _activeController) {
      setState(() {
        _activeController = controller;
      });
    }

    if (seekToStart && _activeController != null) {
      _activeController!.seekTo(clip.startTimeInSource);
    }
    _currentClipIndex = index;
  }

  void _play() {
    final editorState = _latestLoadedState;
    if (editorState == null || _activeController == null) return;

    final activeClip = editorState.currentClips[_currentClipIndex];
    _activeController!.setPlaybackSpeed(activeClip.speed);
    _activeController!.setVolume(activeClip.volume);
    _activeController!.play();

    context.read<EditorBloc>().add(const PlaybackStatusChanged(true));

    _positionSubscription?.cancel();
    _positionSubscription = _activeController!.position.asStream().listen((
      position,
    ) {
      if (!mounted || position == null || _latestLoadedState == null) return;

      // --- Conductor Logic Starts Here ---
      final currentState = _latestLoadedState!;
      final currentClips = currentState.currentClips;
      if (_currentClipIndex >= currentClips.length) return;

      final activeClip = currentClips[_currentClipIndex];
      Duration globalPosition = Duration.zero;
      for (int i = 0; i < _currentClipIndex; i++) {
        globalPosition += currentClips[i].duration;
      }
      final timeInClip = (position - activeClip.startTimeInSource);
      globalPosition += Duration(
        microseconds: (timeInClip.inMicroseconds / activeClip.speed).round(),
      );

      // Update the BLoC with the new global position
      context.read<EditorBloc>().add(
        VideoPositionChanged(globalPosition, currentState.videoDuration),
      );

      // ✨ FIX: This is the new "conductor" logic.
      // It checks every audio clip on every tick of the video player's clock.
      for (final audioClip in currentState.audioClips) {
        final player = _audioPlayers[audioClip.uniqueId];
        if (player == null) continue;

        final clipStart = audioClip.startTimeInTimeline;
        final clipEnd = clipStart + audioClip.duration;
        final isWithinBounds =
            globalPosition >= clipStart && globalPosition < clipEnd;

        // If it should be playing but isn't, start it from the correct spot.
        if (isWithinBounds && !player.playing) {
          player.setVolume(audioClip.volume); // Set volume for the audio clip
          player.seek(globalPosition - clipStart);
          player.play();
        }
        // If it shouldn't be playing but is, stop it.
        else if (!isWithinBounds && player.playing) {
          player.pause();
        }
      }

      // Check if the main video clip has ended
      if (position >= activeClip.endTimeInSource) {
        final nextClipIndex = _currentClipIndex + 1;
        if (nextClipIndex < currentClips.length) {
          _setActiveClip(nextClipIndex, currentClips, seekToStart: true);
          _play(); // Recursively call play for the next clip
        } else {
          _pause();
          _setActiveClip(0, currentClips, seekToStart: true);
        }
      }
    });
  }

  void _pause() {
    _activeController?.pause();

    // ✨ FIX: Also pause all the audio players.
    for (var player in _audioPlayers.values) {
      player.pause();
    }

    _positionSubscription?.cancel();
    context.read<EditorBloc>().add(const PlaybackStatusChanged(false));
  }

  void _onPlayPause() {
    if (_activeController?.value.isPlaying ?? false) {
      _pause();
    } else {
      _play();
    }
  }

  void _onTimelineScrolled(Duration newPosition) {
    final editorState = _latestLoadedState;
    if (editorState == null) return;

    context.read<EditorBloc>().add(
      VideoPositionChanged(newPosition, editorState.videoDuration),
    );
    _updateActiveClipForPosition(
      newPosition,
      editorState.currentClips,
      seek: true,
    );

    // ✨ FIX: When scrubbing, correctly seek or stop audio players.
    for (final audioClip in editorState.audioClips) {
      final player = _audioPlayers[audioClip.uniqueId];
      if (player == null) continue;

      final seekPosition = newPosition - audioClip.startTimeInTimeline;

      if (seekPosition >= Duration.zero && seekPosition < audioClip.duration) {
        player.seek(seekPosition);
      } else {
        // If scrubbing outside the clip, ensure it's paused and reset.
        player.pause();
        player.seek(Duration.zero);
      }
    }
  }

  void _updateActiveClipForPosition(
    Duration globalPosition,
    List<VideoClip> clips, {
    bool seek = false,
  }) {
    if (clips.isEmpty) return;
    Duration cumulativeDuration = Duration.zero;
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final clipEnd = cumulativeDuration + clip.duration;
      if (globalPosition >= cumulativeDuration && globalPosition < clipEnd) {
        if (_currentClipIndex != i || _activeController == null) {
          _setActiveClip(i, clips);
        }
        if (seek && _activeController != null) {
          final timeIntoClip = globalPosition - cumulativeDuration;
          final seekPosInSource =
              clip.startTimeInSource +
              Duration(
                microseconds: (timeIntoClip.inMicroseconds * clip.speed)
                    .round(),
              );
          _activeController!.seekTo(seekPosInSource);
        }
        return;
      }
      cumulativeDuration = clipEnd;
    }
    _setActiveClip(clips.length - 1, clips, seekToStart: false);
    _activeController?.seekTo(clips.last.endTimeInSource);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          // ✨ FIX 3: Keep the state variable updated on every state change.
          if (state is EditorLoaded) {
            // This is the crucial step. We capture the latest valid state here.
            _latestLoadedState = state;

            _onClipsChanged(state.currentClips);

            // ✨ ADD: Check if the audio clips have changed and update players if they have.
            if (!listEquals(_lastKnownAudioClips, state.audioClips)) {
              _updateAudioPlayers(state.audioClips);
            }
            if (state.selectedClipIndex != null &&
                _currentToolbar != EditorToolbar.edit) {
              setState(() => _currentToolbar = EditorToolbar.edit);
            } else if (state.selectedClipIndex == null &&
                (_currentToolbar == EditorToolbar.edit)) {
              setState(() => _currentToolbar = EditorToolbar.main);
            }
          }
        },
        builder: (context, state) {
          if (state is! EditorLoaded) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is EditorProcessing &&
              state.type == ProcessingType.export) {
            return ExportingScreen(
              processingState: state,
              previewController: _activeController,
            );
          }

          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('Editor'),
              backgroundColor: Colors.black,
              elevation: 0,
              // The WillPopScope handles the back button automatically
              leading: const BackButton(color: Colors.white),
              actions: [
                GestureDetector(
                  onTap: () async {
                    final ExportSettings? settings =
                        await showModalBottomSheet<ExportSettings>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => const ExportOptionsSheet(),
                        );

                    if (settings != null && context.mounted) {
                      // Pass the settings object into the event
                      context.read<EditorBloc>().add(ExportStarted(settings));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Export',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              // Use Column instead of Stack for the main layout
              children: [
                VideoViewport(controller: _activeController),
                PlaybackControls(loadedState: state, onPlayPause: _onPlayPause),
                TimelineArea(
                  loadedState: state,
                  onScroll: _onTimelineScrolled,
                  onDragStart: () {
                    _wasPlayingBeforeDrag =
                        _activeController?.value.isPlaying ?? false;
                    if (_wasPlayingBeforeDrag) _pause();
                  },
                  onDragEnd: () {
                    if (_wasPlayingBeforeDrag) _play();
                  },
                ),
              ],
            ),
            bottomNavigationBar: Builder(
              builder: (context) {
                switch (_currentToolbar) {
                  case EditorToolbar.main:
                    return MainToolbar(
                      currentIndex: _selectedToolIndex,
                      onTap: (index) {
                        setState(() => _selectedToolIndex = index);
                        if (index == 0) {
                          setState(() => _currentToolbar = EditorToolbar.edit);
                          if (state.selectedClipIndex == null &&
                              state.currentClips.isNotEmpty) {
                            context.read<EditorBloc>().add(const ClipTapped(0));
                          }
                        } else if (index == 1) {
                          setState(() => _currentToolbar = EditorToolbar.audio);
                        } else if (index == 3) {
                          context.read<EditorBloc>().add(
                            StabilizationStarted(),
                          );
                        }
                      },
                    );
                  case EditorToolbar.audio:
                    return AudioToolbar(
                      onBack: () =>
                          setState(() => _currentToolbar = EditorToolbar.main),
                    );
                  case EditorToolbar.edit:
                    return const EditToolbar();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
