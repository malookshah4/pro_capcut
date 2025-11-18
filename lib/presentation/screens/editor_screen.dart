import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/_video_viewport.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/exporting_screen.dart';
import 'package:pro_capcut/presentation/widgets/procssing_overlay.dart';
import 'package:pro_capcut/presentation/widgets/timeline_area.dart';
import 'package:pro_capcut/presentation/widgets/text_preview_layer.dart'; // NEW IMPORT
import 'package:pro_capcut/utils/PlaybackCoordinator.dart';

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

  @override
  void initState() {
    super.initState();
    _coordinator = PlaybackCoordinator();

    _coordinator.position.addListener(() {
      if (mounted) {
        context.read<EditorBloc>().add(
          VideoPositionChanged(_coordinator.position.value),
        );
      }
    });

    _coordinator.isPlaying.addListener(() {
      if (mounted) {
        context.read<EditorBloc>().add(
          PlaybackStatusChanged(_coordinator.isPlaying.value),
        );
      }
    });
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  void _onPlayPause() {
    final isPlaying = context.read<EditorBloc>().state as EditorLoaded;
    if (isPlaying.isPlaying) {
      _coordinator.pause();
    } else {
      _coordinator.play();
    }
  }

  Widget _buildBottomToolbar(EditorLoaded state) {
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      return MainToolbar(currentIndex: 0, onTap: (i) {});
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
          _coordinator.updateTimeline(state.project.tracks);
          if ((state.videoPosition - _coordinator.position.value).abs() >
                  const Duration(milliseconds: 100) &&
              !state.isPlaying) {
            _coordinator.seek(state.videoPosition);
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
                Column(
                  children: [
                    // --- Video Viewport Container ---
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. The Video Player
                          ValueListenableBuilder(
                            valueListenable: _coordinator.activeController,
                            builder: (context, controller, child) {
                              return VideoViewport(controller: controller);
                            },
                          ),
                          // 2. The Text Overlay Layer (Transparent on top)
                          // We use ValueListenableBuilder to update it on every frame (playback)
                          ValueListenableBuilder<Duration>(
                            valueListenable: _coordinator.position,
                            builder: (context, position, child) {
                              return TextPreviewLayer(currentTime: position);
                            },
                          ),
                        ],
                      ),
                    ),

                    // --- Controls & Timeline ---
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
                    previewController: _coordinator.activeController.value,
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
            },
          ),
        ),
      ],
    );
  }
}
