import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/_video_viewport.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/exporting_screen.dart';
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
      // The child of BlocProvider is now our new ChangeNotifierProvider
      child: EditorView(),
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

      // FIX: This logic correctly calculates the global position and handles clip transitions
      Duration globalPosition = Duration.zero;
      for (int i = 0; i < _currentClipIndex; i++) {
        globalPosition += currentClips[i].duration;
      }
      final timeInClip = (position - activeClip.startTimeInSource);
      globalPosition += Duration(
        microseconds: (timeInClip.inMicroseconds / activeClip.speed).round(),
      );

      // This event update drives the playhead time and timeline scrolling
      context.read<EditorBloc>().add(
        VideoPositionChanged(globalPosition, currentState.videoDuration),
      );

      if (position >= activeClip.endTimeInSource) {
        final nextClipIndex = _currentClipIndex + 1;
        if (nextClipIndex < currentClips.length) {
          // Seamlessly transition to the next clip
          _setActiveClip(nextClipIndex, currentClips, seekToStart: true);
          _play();
        } else {
          // Reached the end of the timeline
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
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded) {
          _onClipsChanged(state.currentClips);

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

        if (state is EditorProcessing && state.type == ProcessingType.export) {
          return ExportingScreen(
            processingState: state,
            // Pass the active controller to show a preview
            previewController: _activeController,
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
              GestureDetector(
                onTap: () async {
                  // Show the bottom sheet and wait for a result
                  final ExportSettings? settings =
                      await showModalBottomSheet<ExportSettings>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => const ExportOptionsSheet(),
                      );

                  // If the user confirmed, settings will not be null
                  if (settings != null && context.mounted) {
                    // TODO: In the future, pass settings to the event
                    // context.read<EditorBloc>().add(ExportStarted(settings));
                    context.read<EditorBloc>().add(ExportStarted());
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
          body: Stack(
            children: [
              Column(
                children: [
                  VideoViewport(controller: _activeController),
                  PlaybackControls(
                    loadedState: state,
                    onPlayPause: _onPlayPause,
                  ),
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
