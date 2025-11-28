import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/screens/exporting_screen.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/overlay_preview_layer.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/procssing_overlay.dart';
import 'package:pro_capcut/presentation/widgets/timeline_area.dart';
import 'package:pro_capcut/presentation/widgets/text_preview_layer.dart';
import 'package:pro_capcut/presentation/widgets/ratio_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/transition_renderer.dart';
import 'package:pro_capcut/utils/PlaybackCoordinator.dart';
import 'package:pro_capcut/utils/thumbnail_utils.dart';
import 'package:video_player/video_player.dart';

class EditorScreen extends StatelessWidget {
  final Project project;
  const EditorScreen({super.key, required this.project});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditorBloc()..add(EditorProjectLoaded(project)),
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
  late final PlaybackCoordinator _coordinator;
  String? _tempThumbnailPath;

  int _lastVersion = -1;

  @override
  void initState() {
    super.initState();
    _coordinator = PlaybackCoordinator();

    // Listen to Coordinator position updates (e.g. during playback)
    _coordinator.position.addListener(() {
      if (mounted && _coordinator.isPlaying.value) {
        // Only sync back to Bloc if actively playing to avoid loops during seek
        context.read<EditorBloc>().add(
          VideoPositionChanged(_coordinator.position.value),
        );
      }
    });

    // Listen to Coordinator playing state (e.g. if video finishes and pauses itself)
    _coordinator.isPlaying.addListener(() {
      if (mounted) {
        final blocState = context.read<EditorBloc>().state;
        if (blocState is EditorLoaded &&
            blocState.isPlaying != _coordinator.isPlaying.value) {
          context.read<EditorBloc>().add(
            PlaybackStatusChanged(_coordinator.isPlaying.value),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    if (_tempThumbnailPath != null) {
      ThumbnailUtils.deleteThumbnail(_tempThumbnailPath);
    }
    _coordinator.dispose();
    super.dispose();
  }

  void _onPlayPause() {
    final state = context.read<EditorBloc>().state;
    if (state is EditorLoaded) {
      // Toggle state in Bloc. The Listener below will handle the Coordinator.
      context.read<EditorBloc>().add(PlaybackStatusChanged(!state.isPlaying));
    }
  }

  Future<void> _onAddMainClip() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) {
      context.read<EditorBloc>().add(ClipAdded(File(video.path)));
    }
  }

  Widget _buildCanvas(EditorLoaded state) {
    return ValueListenableBuilder<VideoPlayerController?>(
      valueListenable: _coordinator.activeController,
      builder: (context, activeController, child) {
        if (activeController == null || !activeController.value.isInitialized) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final double videoRatio = activeController.value.aspectRatio;
        final double? projectRatio = state.project.canvasAspectRatio;
        final double effectiveCanvasRatio = projectRatio ?? videoRatio;

        return Container(
          color: const Color(0xFF1A1A1A),
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: effectiveCanvasRatio,
            child: Container(
              color: Colors.black,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Main video with transition support
                    Center(
                      child: AspectRatio(
                        aspectRatio: videoRatio,
                        child: ValueListenableBuilder<VideoPlayerController?>(
                          valueListenable: _coordinator.incomingController,
                          builder: (context, incomingController, child) {
                            return ValueListenableBuilder<double>(
                              valueListenable: _coordinator.transitionProgress,
                              builder: (context, progress, child) {
                                return ValueListenableBuilder<String?>(
                                  valueListenable: _coordinator.currentTransition,
                                  builder: (context, transitionType, child) {
                                    return TransitionRenderer(
                                      activeController: activeController,
                                      incomingController: incomingController,
                                      transitionType: transitionType,
                                      progress: progress,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    // Overlays
                    ValueListenableBuilder<Duration>(
                      valueListenable: _coordinator.position,
                      builder: (context, position, child) {
                        return OverlayPreviewLayer(
                          currentTime: position,
                          coordinator: _coordinator,
                        );
                      },
                    ),
                    // Text overlays
                    ValueListenableBuilder<Duration>(
                      valueListenable: _coordinator.position,
                      builder: (context, position, child) {
                        return TextPreviewLayer(currentTime: position);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomToolbar(EditorLoaded state) {
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      return MainToolbar(
        currentIndex: 0,
        onTap: (index) async {
          if (index == 3) {
            final double? result = await showModalBottomSheet<double?>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const RatioOptionsSheet(),
            );
            if (context.mounted) {
              context.read<EditorBloc>().add(ProjectCanvasRatioChanged(result));
            }
          }
        },
      );
    }

    try {
      final track = state.project.tracks.firstWhere(
        (t) => t.id == state.selectedTrackId,
      );
      final clip = track.clips.firstWhere(
        (c) => (c as TimelineClip).id == state.selectedClipId,
      );
      if (clip is TextClip) {
        return TextToolbar(clip: clip, trackId: track.id);
      } else {
        return const EditToolbar();
      }
    } catch (e) {
      return const EditToolbar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded) {
          // 1. Handle Exporting (Pause)
          if (state.isProcessing &&
              state.processingType == ProcessingType.export) {
            _coordinator.pause();
          }

          // 2. Handle Project Updates (Reload Timeline)
          if (state.version != _lastVersion) {
            _lastVersion = state.version;
            _coordinator.updateTimeline(state.project.tracks);
          }

          // 3. Handle Seeking (Manual Drag)
          // If position changed significantly AND we are not playing, seek.
          final diff = (state.videoPosition - _coordinator.position.value)
              .abs();
          if (diff > const Duration(milliseconds: 150) && !state.isPlaying) {
            _coordinator.seek(state.videoPosition);
          }

          // 4. --- THE FIX: Sync Play/Pause State ---
          // If Bloc says playing, but Coordinator stopped, Play.
          // If Bloc says paused, but Coordinator playing, Pause.
          if (state.isPlaying != _coordinator.isPlaying.value) {
            if (state.isPlaying) {
              _coordinator.play();
            } else {
              _coordinator.pause();
            }
          }
        }
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PopScope(
          canPop: true,
          onPopInvoked: (_) {
            context.read<EditorBloc>().add(EditorProjectSaved());
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF1A1A1A),
            appBar: _buildAppBar(context, state),
            body: Stack(
              children: [
                if (state.processingType != ProcessingType.export)
                  Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: _buildCanvas(state),
                      ),
                      PlaybackControls(
                        loadedState: state,
                        onPlayPause: _onPlayPause,
                        isPlayingNotifier: _coordinator.isPlaying,
                        positionNotifier: _coordinator.position,
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              TimelineArea(
                                state: state,
                                positionNotifier: _coordinator.position,
                                onAddClip: _onAddMainClip,
                              ),
                              const Align(
                                alignment: Alignment.center,
                                child: Playhead(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomToolbar(state),
                    ],
                  ),

                if (state.isProcessing &&
                    state.processingType != ProcessingType.export)
                  ProcessingOverlay(processingState: state),

                if (state.isProcessing &&
                    state.processingType == ProcessingType.export)
                  ExportingScreen(
                    processingState: state,
                    thumbnailPath: _tempThumbnailPath,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, EditorLoaded state) {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          context.read<EditorBloc>().add(EditorProjectSaved());
          Navigator.of(context).pop();
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final settings = await showModalBottomSheet<ExportSettings>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => const ExportOptionsSheet(),
              );
              if (settings != null && context.mounted) {
                _coordinator.pause();
                try {
                  final videoTrack = state.project.tracks.firstWhere(
                    (t) => t.type == TrackType.video,
                  );
                  if (videoTrack.clips.isNotEmpty) {
                    final firstClip = videoTrack.clips.first as VideoClip;
                    _tempThumbnailPath =
                        await ThumbnailUtils.generateAndSaveThumbnail(
                          firstClip.sourcePath,
                          "export_cover_${DateTime.now().millisecondsSinceEpoch}",
                        );
                  }
                } catch (e) {
                  print("Thumbnail generation failed: $e");
                }
                if (context.mounted) {
                  context.read<EditorBloc>().add(ExportStarted(settings));
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
