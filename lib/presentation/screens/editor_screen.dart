import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/_video_viewport.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/procssing_overlay.dart';
import 'package:pro_capcut/presentation/widgets/timeline_area.dart';
import 'package:video_player/video_player.dart';

class EditorScreen extends StatelessWidget {
  final File videoFile;
  const EditorScreen({super.key, required this.videoFile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditorBloc()..add(EditorVideoInitialized(videoFile)),
      child: const EditorView(),
    );
  }
}

class EditorView extends StatefulWidget {
  const EditorView({super.key});
  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  Map<String, VideoPlayerController> _controllers = {};
  VideoPlayerController? _activeController;
  int _currentClipIndex = 0;
  StreamSubscription<Duration?>? _positionSubscription;

  EditorToolbar _currentToolbar = EditorToolbar.main;
  int _selectedToolIndex = 0;
  bool _wasPlayingBeforeDrag = false;
  List<VideoClip> _lastKnownClips = [];

  @override
  void dispose() {
    _positionSubscription?.cancel();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
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

    for (final oldController in oldControllers.values) {
      oldController.dispose();
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

    if (controller != null) {
      controller.setPlaybackSpeed(clip.speed);
    }

    if (controller != _activeController) {
      setState(() {
        _activeController = controller;
      });
    }

    if (seekToStart && _activeController != null) {
      _activeController!.seekTo(clip.startTimeInSource);
      Duration globalPosition = Duration.zero;
      for (int i = 0; i < index; i++) {
        globalPosition += clips[i].duration;
      }
      final totalDuration = clips.fold(
        Duration.zero,
        (prev, clip) => prev + clip.duration,
      );
      context.read<EditorBloc>().add(
        VideoPositionChanged(globalPosition, totalDuration),
      );
    }

    _currentClipIndex = index;
  }

  void _play() {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded || _activeController == null) return;

    final clips = editorState.currentClips;
    if (_currentClipIndex >= clips.length) return;

    final activeClip = clips[_currentClipIndex];
    _activeController!.setPlaybackSpeed(activeClip.speed);
    _activeController!.play();

    context.read<EditorBloc>().add(const PlaybackStatusChanged(true));

    _positionSubscription?.cancel();
    _positionSubscription = _activeController!.position.asStream().listen((
      position,
    ) {
      if (!mounted || position == null) return;

      final currentState = context.read<EditorBloc>().state as EditorLoaded;
      final currentClips = currentState.currentClips;
      if (_currentClipIndex >= currentClips.length) return;
      final activeClip = currentClips[_currentClipIndex];

      Duration globalPosition = Duration.zero;
      for (int i = 0; i < _currentClipIndex; i++) {
        globalPosition += currentClips[i].duration;
      }
      globalPosition +=
          ((position - activeClip.startTimeInSource) * (1 / activeClip.speed));

      context.read<EditorBloc>().add(
        VideoPositionChanged(globalPosition, currentState.videoDuration),
      );

      if (position >= activeClip.endTimeInSource) {
        final nextClipIndex = _currentClipIndex + 1;
        if (nextClipIndex < currentClips.length) {
          _setActiveClip(nextClipIndex, currentClips, seekToStart: true);
          _play();
        } else {
          _pause();
          _setActiveClip(0, currentClips, seekToStart: true);
        }
      }
    });
  }

  void _pause() {
    _activeController?.pause();
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
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final clips = editorState.currentClips;

    context.read<EditorBloc>().add(
      VideoPositionChanged(newPosition, editorState.videoDuration),
    );

    _updateActiveClipForPosition(newPosition, clips, seek: true);
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
              clip.startTimeInSource + (timeIntoClip * clip.speed);
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
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded) {
          if (!listEquals(_lastKnownClips, state.currentClips)) {
            _lastKnownClips = List.from(state.currentClips);
            _updateControllers(state.currentClips);
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

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Editor'),
            backgroundColor: Colors.black,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            actions: [
              TextButton(
                onPressed: () =>
                    context.read<EditorBloc>().add(ExportStarted()),
                child: const Text(
                  'Export',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 16),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  VideoViewport(controller: _activeController),
                  PlaybackControls(
                    loadedState: state,
                    onPlayPause: _onPlayPause,
                  ),
                  // This is the call that was causing errors
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
              if (state is EditorProcessing)
                ProcessingOverlay(processingState: state),
            ],
          ),
          bottomNavigationBar: Builder(
            builder: (context) {
              switch (_currentToolbar) {
                case EditorToolbar.main:
                  return MainToolbar(
                    currentIndex: _selectedToolIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedToolIndex = index;
                      });
                      if (index == 0) {
                        setState(() => _currentToolbar = EditorToolbar.edit);
                        if (state.selectedClipIndex == null &&
                            state.currentClips.isNotEmpty) {
                          context.read<EditorBloc>().add(const ClipTapped(0));
                        }
                      } else if (index == 1) {
                        setState(() => _currentToolbar = EditorToolbar.audio);
                      } else if (index == 3) {
                        context.read<EditorBloc>().add(StabilizationStarted());
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
    );
  }
}
