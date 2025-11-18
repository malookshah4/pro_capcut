import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const TimelineArea({
    super.key,
    required this.state,
    required this.positionNotifier,
  });

  @override
  State<TimelineArea> createState() => _TimelineAreaState();
}

class _TimelineAreaState extends State<TimelineArea> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  double _pixelsPerSecond = 60.0;
  double _basePixelsPerSecond = 60.0;
  bool _isInteracting = false;

  bool _isTrimming = false;
  bool _isMovingClip = false;
  Axis? _lockedAxis;

  // --- Haptic State ---
  double _accumulatedHapticDelta = 0.0;

  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    widget.positionNotifier.addListener(_syncScrollWithPosition);
    _horizontalController.addListener(_onHorizontalScroll);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    widget.positionNotifier.removeListener(_syncScrollWithPosition);
    _horizontalController.removeListener(_onHorizontalScroll);
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _onHorizontalScroll() {
    if (_isInteracting && !_isTrimming && !_isMovingClip) {
      final newPositionMs =
          (_horizontalController.offset / _pixelsPerSecond) * 1000;
      context.read<EditorBloc>().add(
        VideoPositionChanged(Duration(milliseconds: newPositionMs.round())),
      );
    }
  }

  void _syncScrollWithPosition() {
    if (_isInteracting) return;
    final currentPosSeconds =
        widget.positionNotifier.value.inMilliseconds / 1000;
    final expectedOffset = currentPosSeconds * _pixelsPerSecond;
    if (_horizontalController.hasClients) {
      if ((_horizontalController.offset - expectedOffset).abs() > 1.0) {
        _horizontalController.jumpTo(expectedOffset);
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isTrimming || _isMovingClip) return;
    setState(() {
      _isInteracting = true;
      _lockedAxis = null;
    });
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
      final currentTimeSeconds =
          widget.positionNotifier.value.inMilliseconds / 1000.0;
      final newScrollOffset = currentTimeSeconds * newScale;
      setState(() => _pixelsPerSecond = newScale);
      if (_horizontalController.hasClients)
        _horizontalController.jumpTo(newScrollOffset);
    } else {
      final double deltaX = details.focalPointDelta.dx;
      final double deltaY = details.focalPointDelta.dy;
      if (_lockedAxis == null) {
        if (deltaX.abs() > deltaY.abs() && deltaX.abs() > 2.0)
          _lockedAxis = Axis.horizontal;
        else if (deltaY.abs() > deltaX.abs() && deltaY.abs() > 2.0)
          _lockedAxis = Axis.vertical;
      }
      if (_lockedAxis == Axis.horizontal && _horizontalController.hasClients) {
        final double newOffset = _horizontalController.offset - deltaX;
        final double max = _horizontalController.position.maxScrollExtent;
        final double min = _horizontalController.position.minScrollExtent;
        _horizontalController.jumpTo(newOffset.clamp(min, max));
      } else if (_lockedAxis == Axis.vertical &&
          _verticalController.hasClients) {
        final double newOffset = _verticalController.offset - deltaY;
        final double max = _verticalController.position.maxScrollExtent;
        final double min = _verticalController.position.minScrollExtent;
        _verticalController.jumpTo(newOffset.clamp(min, max));
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isTrimming || _isMovingClip) return;
    setState(() {
      _isInteracting = false;
      _lockedAxis = null;
    });
  }

  void _onClipMoveStart() {
    setState(() {
      _isMovingClip = true;
      _accumulatedHapticDelta = 0.0;
    });
  }

  // --- FIX: Accept clipId here explicitly ---
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

    // Use the passed clipId, NOT state.selectedClipId!
    context.read<EditorBloc>().add(
      ClipMoved(
        trackId: trackId,
        clipId: clipId,
        delta: Duration(microseconds: deltaMicroseconds),
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final touchX = details.globalPosition.dx;
    const edgeThreshold = 50.0;

    if (touchX < edgeThreshold) {
      _startAutoScroll(-10.0, trackId, clipId);
    } else if (touchX > screenWidth - edgeThreshold) {
      _startAutoScroll(10.0, trackId, clipId);
    } else {
      _stopAutoScroll();
    }
  }

  void _onClipMoveEnd() {
    setState(() => _isMovingClip = false);
    _stopAutoScroll();
    context.read<EditorBloc>().add(EditorProjectSaved());
  }

  void _startAutoScroll(double speed, String trackId, String clipId) {
    if (_autoScrollTimer != null && _autoScrollSpeed == speed) return;
    _autoScrollSpeed = speed;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!_horizontalController.hasClients) return;
      final currentOffset = _horizontalController.offset;
      final newOffset = currentOffset + _autoScrollSpeed;
      final maxOffset = _horizontalController.position.maxScrollExtent;

      if (newOffset >= 0 && newOffset <= maxOffset) {
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
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final EditorTrack? videoTrack = widget.state.project.tracks
        .where((t) => t.type == TrackType.video)
        .firstOrNull;
    final List<EditorTrack> overlayTracks = widget.state.project.tracks
        .where((t) => t.type != TrackType.video)
        .toList();
    if (videoTrack == null)
      return const Center(child: Text("Error: No video track found."));

    final double totalContentWidth =
        (widget.state.videoDuration.inMilliseconds / 1000) * _pixelsPerSecond;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _AllowMultipleScaleRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _AllowMultipleScaleRecognizer
                      >(() => _AllowMultipleScaleRecognizer(), (instance) {
                        instance.onStart = _onScaleStart;
                        instance.onUpdate = _onScaleUpdate;
                        instance.onEnd = _onScaleEnd;
                      }),
                },
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalContentWidth + screenWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Main Video Track
                        TimelineTrackWidget(
                          track: videoTrack,
                          pixelsPerSecond: _pixelsPerSecond,
                          horizontalPadding: screenWidth / 2,
                          selectedClipId: widget.state.selectedClipId,
                          onClipTapped: (trackId, clipId) =>
                              context.read<EditorBloc>().add(
                                ClipTapped(trackId: trackId, clipId: clipId),
                              ),
                          onTrimStart: () => setState(() => _isTrimming = true),
                          onTrimEnd: () {
                            setState(() => _isTrimming = false);
                            context.read<EditorBloc>().add(
                              ClipRippleRequested(videoTrack.id),
                            );
                          },
                        ),

                        // Overlay Tracks (Scrollable)
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            scrollDirection: Axis.vertical,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                if (overlayTracks.isNotEmpty)
                                  ...overlayTracks.map((track) {
                                    return TimelineTrackWidget(
                                      track: track,
                                      pixelsPerSecond: _pixelsPerSecond,
                                      horizontalPadding: screenWidth / 2,
                                      selectedClipId:
                                          widget.state.selectedClipId,
                                      onClipTapped: (trackId, clipId) =>
                                          context.read<EditorBloc>().add(
                                            ClipTapped(
                                              trackId: trackId,
                                              clipId: clipId,
                                            ),
                                          ),
                                      onTrimStart: () =>
                                          setState(() => _isTrimming = true),
                                      onTrimEnd: () {
                                        setState(() => _isTrimming = false);
                                        context.read<EditorBloc>().add(
                                          EditorProjectSaved(),
                                        );
                                      },
                                      onMoveStart: _onClipMoveStart,

                                      // --- FIX: Correctly receiving 3 arguments from child ---
                                      onMoveUpdate: (clipId, delta, details) =>
                                          _onClipMoveUpdate(
                                            track.id,
                                            clipId,
                                            delta,
                                            details,
                                          ),

                                      onMoveEnd: _onClipMoveEnd,
                                    );
                                  }),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
            if (result != null && context.mounted) {
              context.read<EditorBloc>().add(
                AudioTrackAdded(File(result.files.single.path!)),
              );
            }
          }),
          _buildButton(Icons.text_fields, "Text", () async {
            final result = await showModalBottomSheet<TextEditorResult>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const TextEditorSheet(),
            );
            if (result != null && context.mounted) {
              context.read<EditorBloc>().add(
                TextTrackAdded(result.text, result.style),
              );
            }
          }),
          _buildButton(Icons.video_library, "Overlay", () async {
            final ImagePicker picker = ImagePicker();
            final XFile? video = await picker.pickVideo(
              source: ImageSource.gallery,
            );
            if (video != null && context.mounted) {
              context.read<EditorBloc>().add(
                OverlayTrackAdded(File(video.path)),
              );
            }
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
