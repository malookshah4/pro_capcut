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
  // --- REWRITTEN: Controller management for the virtual timeline ---
  VideoPlayerController? _activeController;
  final Map<String, VideoPlayerController> _controllers = {};
  int _currentClipIndex = 0;
  List<VideoClip> _currentClips = [];
  Duration _totalTimelineDuration = Duration.zero;
  bool _isSeeking = false;

  EditorToolbar _currentToolbar = EditorToolbar.main;
  int _selectedToolIndex = 0;
  final ScrollController _timelineScrollController = ScrollController();
  bool _wasPlayingBeforeDrag = false;

  @override
  void dispose() {
    // Dispose all created controllers
    for (var controller in _controllers.values) {
      controller.removeListener(_playbackListener);
      controller.dispose();
    }
    _timelineScrollController.dispose();
    super.dispose();
  }

  // --- NEW: Initializes or updates controllers based on the virtual timeline ---
  Future<void> _initializeControllers(List<VideoClip> clips) async {
    _currentClips = clips;
    _totalTimelineDuration = clips.fold(
      Duration.zero,
      (prev, clip) => prev + clip.duration,
    );

    // Find all unique video paths from the timeline instructions
    final uniquePaths = clips.map((c) => c.playablePath).toSet();

    // Dispose controllers that are no longer needed
    final pathsToRemove = _controllers.keys.where(
      (p) => !uniquePaths.contains(p),
    );
    for (var path in pathsToRemove) {
      _controllers[path]?.dispose();
      _controllers.remove(path);
    }

    // Create and initialize controllers for new video paths
    for (var path in uniquePaths) {
      if (!_controllers.containsKey(path)) {
        final newController = VideoPlayerController.file(File(path));
        _controllers[path] = newController;
        await newController.initialize();
        newController.setLooping(false); // We handle looping manually
      }
    }

    // Set the initial active controller
    if (clips.isNotEmpty) {
      _activeController = _controllers[clips.first.playablePath];
      // Seek to the start of the first clip's segment
      await _activeController?.seekTo(clips.first.startTimeInSource);
      setState(() {});
    }

    // Add listener to the active controller
    _activeController?.removeListener(_playbackListener);
    _activeController?.addListener(_playbackListener);

    // Update the total duration in the BLoC
    context.read<EditorBloc>().add(
      VideoPositionChanged(
        Duration.zero, // Start at the beginning
        _totalTimelineDuration,
      ),
    );
  }

  // --- NEW: The core playback logic for the virtual timeline ---
  void _playbackListener() {
    if (_activeController == null ||
        !_activeController!.value.isInitialized ||
        _currentClips.isEmpty ||
        _isSeeking) {
      return;
    }

    final editorBloc = context.read<EditorBloc>();
    final currentClip = _currentClips[_currentClipIndex];
    final positionInSource = _activeController!.value.position;

    // Check if playback has passed the end of the current virtual clip
    if (positionInSource >= currentClip.endTimeInSource) {
      final nextClipIndex = _currentClipIndex + 1;

      if (nextClipIndex < _currentClips.length) {
        // --- Transition to the next clip ---
        _currentClipIndex = nextClipIndex;
        final nextClip = _currentClips[nextClipIndex];

        // Switch the active controller if the next clip uses a different file
        if (_activeController != _controllers[nextClip.playablePath]) {
          _activeController?.removeListener(_playbackListener);
          setState(() {
            _activeController = _controllers[nextClip.playablePath];
          });
          _activeController?.addListener(_playbackListener);
        }

        _activeController?.seekTo(nextClip.startTimeInSource);
        if (editorBloc.state is EditorLoaded &&
            (editorBloc.state as EditorLoaded).isPlaying) {
          _activeController?.play();
        }
      } else {
        // --- End of timeline ---
        _activeController?.pause();
        _activeController?.seekTo(
          currentClip.endTimeInSource,
        ); // Park at the very end
        editorBloc.add(const PlaybackStatusChanged(false));
      }
    }

    // Update global timeline position in BLoC state
    Duration precedingDuration = Duration.zero;
    for (int i = 0; i < _currentClipIndex; i++) {
      precedingDuration += _currentClips[i].duration;
    }
    final positionInClip = positionInSource - currentClip.startTimeInSource;
    final globalPosition = precedingDuration + positionInClip;

    editorBloc.add(
      VideoPositionChanged(globalPosition, _totalTimelineDuration),
    );
  }

  // --- NEW: Handles seek requests from the BLoC ---
  Future<void> _handleSeek(Duration globalPosition) async {
    if (_isSeeking) return;
    setState(() => _isSeeking = true);

    Duration precedingDuration = Duration.zero;
    for (int i = 0; i < _currentClips.length; i++) {
      final clip = _currentClips[i];
      final clipEnd = precedingDuration + clip.duration;

      if (globalPosition <= clipEnd) {
        final positionInClip = globalPosition - precedingDuration;
        final seekInSource = clip.startTimeInSource + positionInClip;

        if (_currentClipIndex != i ||
            _activeController != _controllers[clip.playablePath]) {
          _activeController?.removeListener(_playbackListener);
          setState(() {
            _currentClipIndex = i;
            _activeController = _controllers[clip.playablePath];
          });
          _activeController?.addListener(_playbackListener);
        }

        await _activeController?.seekTo(seekInSource);
        break;
      }
      precedingDuration = clipEnd;
    }

    setState(() => _isSeeking = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      // --- Listen for state changes to trigger UI updates ---
      listenWhen: (prev, curr) {
        if (prev is! EditorLoaded || curr is! EditorLoaded) return true;
        // Re-initialize controllers ONLY when the timeline structure changes
        return !listEquals(prev.currentClips, curr.currentClips) ||
            prev.videoPosition != curr.videoPosition;
      },
      listener: (context, state) {
        if (state is EditorLoaded) {
          // Initialize controllers when the clips change
          if (!listEquals(_currentClips, state.currentClips)) {
            _initializeControllers(state.currentClips);
          }

          // Handle seek requests from the BLoC
          if (state.videoPosition != _activeController?.value.position &&
              !_isSeeking) {
            _handleSeek(state.videoPosition);
          }

          // Toolbar logic remains the same
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

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Color.fromARGB(255, 22, 22, 22),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('Editor'),
              backgroundColor: Colors.black,
              elevation: 0,
              leading: const BackButton(color: Colors.white),
              actions: [
                TextButton(
                  onPressed: () {},
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
                      // --- MODIFIED: Pass active controller and handle play/pause ---
                      controller: _activeController,
                      loadedState: state,
                      onPlayPause: () {
                        final isPlaying =
                            _activeController?.value.isPlaying ?? false;
                        if (isPlaying) {
                          _activeController?.pause();
                        } else {
                          _activeController?.play();
                        }
                        context.read<EditorBloc>().add(
                          PlaybackStatusChanged(!isPlaying),
                        );
                      },
                    ),
                    TimelineArea(
                      controller: _activeController,
                      loadedState: state,
                      timelineScrollController: _timelineScrollController,
                      onDragStart: () {
                        _wasPlayingBeforeDrag =
                            _activeController?.value.isPlaying ?? false;
                        if (_wasPlayingBeforeDrag) {
                          _activeController?.pause();
                        }
                      },
                      onDragEnd: () {
                        if (_wasPlayingBeforeDrag) {
                          _activeController?.play();
                        }
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
                        setState(() => _selectedToolIndex = index);
                        if (index == 1) {
                          setState(() => _currentToolbar = EditorToolbar.audio);
                        } else if (index == 0) {
                          if (state.selectedClipIndex == null) {
                            context.read<EditorBloc>().add(const ClipTapped(0));
                          }
                          setState(() => _currentToolbar = EditorToolbar.edit);
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
          ),
        );
      },
    );
  }
}
