import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/presentation/widgets/_playback_controls.dart';
import 'package:pro_capcut/presentation/widgets/_video_viewport.dart';
import 'package:pro_capcut/presentation/widgets/editor_toolbars.dart';
import 'package:pro_capcut/presentation/widgets/export_options_sheet.dart';
import 'package:pro_capcut/presentation/widgets/exporting_screen.dart';
import 'package:pro_capcut/presentation/widgets/speed_control_sheet.dart';
import 'package:pro_capcut/presentation/widgets/timeline_area.dart';
import 'package:pro_capcut/presentation/widgets/volume_control_sheet.dart';
import 'package:pro_capcut/utils/PlaybackCoordinator.dart';
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
  // The UI state now only holds the coordinator and UI-specific state
  late final PlaybackCoordinator _coordinator;
  bool _wasPlayingBeforeDrag = false;
  EditorToolbar _currentToolbar = EditorToolbar.main;
  int _selectedToolIndex = 0;

  @override
  void initState() {
    super.initState();
    _coordinator = PlaybackCoordinator();
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  /// This logic remains in the UI as it's a UI lifecycle event.
  /// It dispatches an event to the BLoC to handle saving.
  Future<bool> _onWillPop() async {
    if (context.read<EditorBloc>().state is EditorLoaded) {
      context.read<EditorBloc>().add(EditorProjectSaved());
    }
    return true;
  }

  void _onPlayPause() {
    if (_coordinator.isPlaying.value) {
      _coordinator.pause();
    } else {
      _coordinator.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: BlocListener<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state is EditorLoaded) {
            // This is the critical link:
            // When BLoC state changes, we tell the coordinator to update its players.
            _coordinator.updateTimeline(state.currentClips, state.audioClips);

            // This UI-specific logic remains in the view state
            if (state.selectedClipIndex != null &&
                _currentToolbar != EditorToolbar.edit) {
              setState(() => _currentToolbar = EditorToolbar.edit);
            } else if (state.selectedClipIndex == null &&
                (_currentToolbar == EditorToolbar.edit)) {
              setState(() => _currentToolbar = EditorToolbar.main);
            }
          }
        },
        child: BlocBuilder<EditorBloc, EditorState>(
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
                // Pass the current active controller for the preview
                previewController: _coordinator.activeController.value,
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
                      final ExportSettings? settings =
                          await showModalBottomSheet<ExportSettings>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const ExportOptionsSheet(),
                          );

                      if (settings != null && context.mounted) {
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
                children: [
                  // The viewport listens directly to the coordinator's active controller notifier.
                  // This ensures it only rebuilds when the active clip changes, not on every frame.
                  ValueListenableBuilder<VideoPlayerController?>(
                    valueListenable: _coordinator.activeController,
                    builder: (context, controller, child) {
                      return VideoViewport(controller: controller);
                    },
                  ),
                  PlaybackControls(
                    loadedState: state,
                    onPlayPause: _onPlayPause,
                    // Pass the notifiers to the controls for high-frequency updates.
                    isPlayingNotifier: _coordinator.isPlaying,
                    positionNotifier: _coordinator.position,
                  ),
                  TimelineArea(
                    loadedState: state,
                    positionNotifier: _coordinator.position,
                    onScroll: (newPosition) {
                      _coordinator.seek(newPosition);
                    },
                    onDragStart: () {
                      _wasPlayingBeforeDrag = _coordinator.isPlaying.value;
                      if (_wasPlayingBeforeDrag) _coordinator.pause();
                    },
                    onDragEnd: () {
                      if (_wasPlayingBeforeDrag) _coordinator.play();
                    },
                    // NEW: Implement the onTrimUpdate callback
                    onTrimUpdate:
                        ({
                          required int clipIndex,
                          required Duration positionInSource,
                        }) {
                          _coordinator.seekToClipEdge(
                            clipIndex: clipIndex,
                            positionInSource: positionInSource,
                          );
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
                            setState(
                              () => _currentToolbar = EditorToolbar.edit,
                            );
                            if (state.selectedClipIndex == null &&
                                state.currentClips.isNotEmpty) {
                              context.read<EditorBloc>().add(
                                const ClipTapped(0),
                              );
                            }
                          } else if (index == 1) {
                            setState(
                              () => _currentToolbar = EditorToolbar.audio,
                            );
                          } else if (index == 3) {
                            context.read<EditorBloc>().add(
                              StabilizationStarted(),
                            );
                          }
                        },
                      );
                    case EditorToolbar.audio:
                      return AudioToolbar(
                        onBack: () => setState(
                          () => _currentToolbar = EditorToolbar.main,
                        ),
                      );
                    case EditorToolbar.edit:
                      // Now we pass the logic for each button press down to the toolbar.
                      return EditToolbar(
                        onBack: () => context.read<EditorBloc>().add(
                          const ClipTapped(null),
                        ),
                        onDelete: () {
                          if (state.selectedClipIndex != null) {
                            context.read<EditorBloc>().add(ClipDeleted());
                          }
                        },
                        onSplit: () {
                          if (state.selectedClipIndex != null) {
                            context.read<EditorBloc>().add(
                              ClipSplitRequested(
                                clipIndex: state.selectedClipIndex!,
                                // THE FIX: Use the live position from the coordinator
                                splitAt: _coordinator.position.value,
                              ),
                            );
                          }
                        },
                        onSpeed: () {
                          if (state.selectedClipIndex != null) {
                            final selectedClip =
                                state.currentClips[state.selectedClipIndex!];
                            showModalBottomSheet<double>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => SpeedControlSheet(
                                initialSpeed: selectedClip.speed,
                                originalDuration: selectedClip.durationInSource,
                              ),
                            ).then((newSpeed) {
                              if (newSpeed != null) {
                                context.read<EditorBloc>().add(
                                  ClipSpeedChanged(newSpeed),
                                );
                              }
                            });
                          }
                        },
                        onVolume: () {
                          if (state.selectedClipIndex != null) {
                            final selectedClip =
                                state.currentClips[state.selectedClipIndex!];
                            showModalBottomSheet<void>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => BlocProvider.value(
                                value: context.read<EditorBloc>(),
                                child: VolumeControlSheet(
                                  initialVolume: selectedClip.volume,
                                ),
                              ),
                            );
                          }
                        },
                      );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
