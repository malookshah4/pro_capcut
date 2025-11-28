import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/text_style_model.dart';
import 'package:pro_capcut/presentation/widgets/text_editor_sheet.dart';
import 'package:pro_capcut/presentation/widgets/timeline_track_widget.dart';

class TimelineArea extends StatefulWidget {
  final EditorLoaded state;
  final ValueListenable<Duration> positionNotifier;
  final VoidCallback? onAddClip;

  const TimelineArea({
    super.key,
    required this.state,
    required this.positionNotifier,
    this.onAddClip,
  });

  @override
  State<TimelineArea> createState() => _TimelineAreaState();
}

class _TimelineAreaState extends State<TimelineArea> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  double _pixelsPerSecond = 60.0;
  double _basePixelsPerSecond = 60.0;

  // Interaction States
  bool _isManuallyScrolling = false; // User Drag OR Ballistic Fling
  bool _isSyncing = false; // Programmatic scroll (Playback)

  bool _isTrimming = false;
  bool _isMovingClip = false;

  // Helper Variables
  double _accumulatedHapticDelta = 0.0;
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    // Listen to the PlaybackCoordinator (Auto-Scroll)
    widget.positionNotifier.addListener(_syncScrollWithPlayback);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    widget.positionNotifier.removeListener(_syncScrollWithPlayback);
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  // --- 1. Auto-Scroll (Playback -> Timeline) ---
  void _syncScrollWithPlayback() {
    // If user is interacting, ignore playback updates
    if (_isManuallyScrolling || _isTrimming || _isMovingClip) return;

    final currentPosSeconds =
        widget.positionNotifier.value.inMilliseconds / 1000.0;
    final expectedOffset = currentPosSeconds * _pixelsPerSecond;

    if (_horizontalController.hasClients) {
      // Always sync if playing to ensure smooth scrolling during transitions
      if (widget.state.isPlaying) {
        _isSyncing = true; // Lock to prevent feedback loop
        _horizontalController.jumpTo(expectedOffset.clamp(
          0.0,
          _horizontalController.position.maxScrollExtent,
        ));
        _isSyncing = false; // Unlock
      } else {
        // Only jump if the difference is significant when paused (prevents jitter)
        if ((_horizontalController.offset - expectedOffset).abs() > 2.0) {
          _isSyncing = true;
          _horizontalController.jumpTo(expectedOffset.clamp(
            0.0,
            _horizontalController.position.maxScrollExtent,
          ));
          _isSyncing = false;
        }
      }
    }
  }

  // --- 2. Manual Scroll (Timeline -> Video Frame) ---
  bool _onNotification(ScrollNotification notification) {
    // Check if this notification comes from the Horizontal controller
    if (notification.depth != 0) return false;

    if (notification is ScrollStartNotification) {
      if (!_isSyncing) {
        // Only if NOT initiated by playback sync
        _isManuallyScrolling = true;
        if (widget.state.isPlaying) {
          context.read<EditorBloc>().add(const PlaybackStatusChanged(false));
        }
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isManuallyScrolling && _horizontalController.hasClients) {
        _updateVideoFromScroll();
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManuallyScrolling) {
        // Snap / Final update
        _updateVideoFromScroll();
        _isManuallyScrolling = false;
      }
    }
    return true;
  }

  void _updateVideoFromScroll() {
    final newPositionMs =
        (_horizontalController.offset / _pixelsPerSecond) * 1000;
    final clampedMs = newPositionMs < 0 ? 0 : newPositionMs.round();

    // Send SEEK request to Bloc
    context.read<EditorBloc>().add(
      VideoPositionChanged(Duration(milliseconds: clampedMs)),
    );
  }

  // --- Zoom Logic ---
  void _onScaleStart(ScaleStartDetails details) {
    if (_isTrimming || _isMovingClip) return;
    _basePixelsPerSecond = _pixelsPerSecond;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isTrimming || _isMovingClip) return;

    final bool isZooming = (details.scale - 1.0).abs() > 0.05;
    if (isZooming) {
      final newScale = (_basePixelsPerSecond * details.scale).clamp(
        10.0,
        400.0,
      );

      // Maintain relative position
      final currentTimeSeconds =
          widget.positionNotifier.value.inMilliseconds / 1000.0;
      final newScrollOffset = currentTimeSeconds * newScale;

      setState(() => _pixelsPerSecond = newScale);

      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(newScrollOffset);
      }
    }
  }

  // --- Clip Moving Logic ---
  void _onClipMoveStart() {
    setState(() => _isMovingClip = true);
  }

  void _onClipMoveUpdate(
    String trackId,
    String clipId,
    double deltaPixels,
    DragUpdateDetails details,
  ) {
    _accumulatedHapticDelta += deltaPixels;
    if (_accumulatedHapticDelta.abs() > 15.0) {
      HapticFeedback.selectionClick();
      _accumulatedHapticDelta = 0.0;
    }

    final double deltaSeconds = deltaPixels / _pixelsPerSecond;
    final int deltaMicroseconds = (deltaSeconds * 1000000).round();

    context.read<EditorBloc>().add(
      ClipMoved(
        trackId: trackId,
        clipId: clipId,
        delta: Duration(microseconds: deltaMicroseconds),
      ),
    );

    // Edge Auto-Scroll
    final screenWidth = MediaQuery.of(context).size.width;
    final touchX = details.globalPosition.dx;
    if (touchX < 50)
      _startAutoScroll(-10.0, trackId, clipId);
    else if (touchX > screenWidth - 50)
      _startAutoScroll(10.0, trackId, clipId);
    else
      _stopAutoScroll();
  }

  void _onClipMoveEnd() {
    setState(() => _isMovingClip = false);
    _stopAutoScroll();
    context.read<EditorBloc>().add(EditorProjectSaved());
  }

  void _startAutoScroll(double speed, String trackId, String clipId) {
    if (_autoScrollTimer != null) return;
    _autoScrollSpeed = speed;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_horizontalController.hasClients) return;
      final newOffset = _horizontalController.offset + _autoScrollSpeed;
      _horizontalController.jumpTo(newOffset);

      final double deltaSeconds = _autoScrollSpeed / _pixelsPerSecond;
      final int deltaMicroseconds = (deltaSeconds * 1000000).round();
      context.read<EditorBloc>().add(
        ClipMoved(
          trackId: trackId,
          clipId: clipId,
          delta: Duration(microseconds: deltaMicroseconds),
        ),
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final EditorTrack? videoTrack = widget.state.project.tracks
        .where((t) => t.type == TrackType.video)
        .firstOrNull;
    final List<EditorTrack> overlayTracks = widget.state.project.tracks
        .where((t) => t.type != TrackType.video)
        .toList();

    if (videoTrack == null) return const Center(child: Text("No Video Track"));

    // Buffer ensures we can scroll past the last clip to reach the + button
    final double contentWidth =
        (widget.state.videoDuration.inMilliseconds / 1000) * _pixelsPerSecond;
    final double totalScrollableWidth = contentWidth + 200.0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // 1. SCROLLABLE TIMELINE
                  NotificationListener<ScrollNotification>(
                    onNotification: _onNotification,
                    child: RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        _AllowMultipleScaleRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              _AllowMultipleScaleRecognizer
                            >(() => _AllowMultipleScaleRecognizer(), (
                              instance,
                            ) {
                              instance.onStart = _onScaleStart;
                              instance.onUpdate = _onScaleUpdate;
                            }),
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        physics:
                            const ClampingScrollPhysics(), // Better for timelines
                        child: SizedBox(
                          width: totalScrollableWidth + screenWidth,
                          height: constraints.maxHeight,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              // Main Track
                              TimelineTrackWidget(
                                track: videoTrack,
                                pixelsPerSecond: _pixelsPerSecond,
                                horizontalPadding: screenWidth / 2,
                                selectedClipId: widget.state.selectedClipId,
                                onClipTapped: (tid, cid) => context
                                    .read<EditorBloc>()
                                    .add(ClipTapped(trackId: tid, clipId: cid)),
                                onTrimStart: () =>
                                    setState(() => _isTrimming = true),
                                onTrimEnd: () {
                                  setState(() => _isTrimming = false);
                                  context.read<EditorBloc>().add(
                                    ClipRippleRequested(videoTrack.id),
                                  );
                                },
                              ),
                              // Overlay Tracks
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _verticalController,
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      ...overlayTracks.map(
                                        (t) => TimelineTrackWidget(
                                          track: t,
                                          pixelsPerSecond: _pixelsPerSecond,
                                          horizontalPadding: screenWidth / 2,
                                          selectedClipId:
                                              widget.state.selectedClipId,
                                          onClipTapped: (tid, cid) =>
                                              context.read<EditorBloc>().add(
                                                ClipTapped(
                                                  trackId: tid,
                                                  clipId: cid,
                                                ),
                                              ),
                                          onTrimStart: () => setState(
                                            () => _isTrimming = true,
                                          ),
                                          onTrimEnd: () {
                                            setState(() => _isTrimming = false);
                                            context.read<EditorBloc>().add(
                                              EditorProjectSaved(),
                                            );
                                          },
                                          onMoveStart: _onClipMoveStart,
                                          onMoveUpdate: (cid, d, det) =>
                                              _onClipMoveUpdate(
                                                t.id,
                                                cid,
                                                d,
                                                det,
                                              ),
                                          onMoveEnd: _onClipMoveEnd,
                                        ),
                                      ),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. FIXED "ADD CLIP" BUTTON
                  Positioned(
                    right: 16,
                    top: 30,
                    child: GestureDetector(
                      onTap: widget.onAddClip,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _buildAddTrackButtons(),
      ],
    );
  }

  Widget _buildAddTrackButtons() {
    return Container(
      height: 50,
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(Icons.music_note, "Audio", () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
            );
            if (result != null && mounted)
              context.read<EditorBloc>().add(
                AudioTrackAdded(File(result.files.single.path!)),
              );
          }),
          _buildButton(Icons.text_fields, "Text", () async {
            final result = await showModalBottomSheet<TextEditorResult>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const TextEditorSheet(),
            );
            if (result != null && mounted)
              context.read<EditorBloc>().add(
                TextTrackAdded(result.text, result.style),
              );
          }),
          _buildButton(Icons.video_library, "Overlay", () async {
            final ImagePicker picker = ImagePicker();
            final XFile? video = await picker.pickVideo(
              source: ImageSource.gallery,
            );
            if (video != null && mounted)
              context.read<EditorBloc>().add(
                OverlayTrackAdded(File(video.path)),
              );
          }),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      onPressed: onTap,
    );
  }
}

class _AllowMultipleScaleRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
