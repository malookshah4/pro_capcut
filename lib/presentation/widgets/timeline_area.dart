import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/presentation/widgets/placeholder_track.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/video_timeline.dart';

class TimelineArea extends StatefulWidget {
  final EditorLoaded loadedState;
  final ValueListenable<Duration> positionNotifier;
  final Function(Duration) onScroll;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Function({required int clipIndex, required Duration positionInSource})
  onTrimUpdate;

  const TimelineArea({
    super.key,
    required this.loadedState,
    required this.positionNotifier,
    required this.onScroll,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onTrimUpdate,
  });

  @override
  State<TimelineArea> createState() => _TimelineAreaState();
}

enum _DragType { scroll, trimStart, trimEnd, none }

class _TimelineAreaState extends State<TimelineArea> {
  final ScrollController _scrollController = ScrollController();
  double _pixelsPerSecond = 60.0;
  double _basePixelsPerSecond = 60.0;
  _DragType _dragType = _DragType.none;
  int _trimmingClipIndex = -1;
  Duration? _liveTrimDuration;
  Offset? _popupPosition;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    widget.positionNotifier.addListener(_syncScrollWithPosition);
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_syncScrollWithPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncScrollWithPosition() {
    if (_isInteracting) return;
    final expectedOffset =
        (widget.positionNotifier.value.inMilliseconds / 1000) *
        _pixelsPerSecond;
    if (_scrollController.hasClients &&
        (_scrollController.offset - expectedOffset).abs() > 1.0) {
      _scrollController.jumpTo(expectedOffset);
    }
  }

  // --- THIS IS THE CORRECTED GESTURE LOGIC ---

  void _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _isInteracting = true;
    });
    widget.onDragStart();
    _basePixelsPerSecond = _pixelsPerSecond;
    _popupPosition = details.focalPoint;

    // A one-finger drag can be a scroll or a trim.
    if (details.pointerCount == 1) {
      // If a clip is selected, we need to determine if the drag is on a handle.
      if (widget.loadedState.selectedClipIndex != null) {
        _handleTrimStart(details.localFocalPoint);
      } else {
        // If no clip is selected, it can only be a scroll.
        _dragType = _DragType.scroll;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Two-finger pinch is exclusively for zooming.
    if (details.pointerCount > 1) {
      _dragType = _DragType.none; // Prevent any trim/pan during a zoom.
      final newPixelsPerSecond = (_basePixelsPerSecond * details.scale).clamp(
        30.0,
        500.0,
      );
      final currentTimeInSeconds =
          widget.positionNotifier.value.inMilliseconds / 1000.0;
      final maxScroll =
          (widget.loadedState.videoDuration.inMilliseconds /
          1000.0 *
          newPixelsPerSecond);
      final newScrollOffset = (currentTimeInSeconds * newPixelsPerSecond).clamp(
        0.0,
        maxScroll,
      );

      setState(() {
        _pixelsPerSecond = newPixelsPerSecond;
      });
      _scrollController.jumpTo(newScrollOffset);
      return;
    }

    // If we reach here, it's a one-finger drag (pan).
    // The details.focalPointDelta contains the pan movement.
    final dx = details.focalPointDelta.dx;
    setState(() {
      _popupPosition = details.focalPoint;
    });

    if (_dragType == _DragType.scroll) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final newOffset = (_scrollController.offset - dx).clamp(0.0, maxScroll);
      _scrollController.jumpTo(newOffset);
      // Notify coordinator of the new position for the playhead time display
      final newPositionMs = (newOffset / _pixelsPerSecond) * 1000;
      widget.onScroll(Duration(milliseconds: newPositionMs.round()));
    } else if (_dragType == _DragType.trimStart ||
        _dragType == _DragType.trimEnd) {
      _handleTrimUpdate(dx);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    setState(() {
      _isInteracting = false;
      _liveTrimDuration = null;
      _popupPosition = null;
    });

    if (_dragType == _DragType.trimStart || _dragType == _DragType.trimEnd) {
      context.read<EditorBloc>().add(ClipTrimEnded());
    }
    _dragType = _DragType.none;
    _trimmingClipIndex = -1;
    widget.onDragEnd();
  }

  void _handleTrimStart(Offset localPosition) {
    _trimmingClipIndex = widget.loadedState.selectedClipIndex!;
    final selectedClip = widget.loadedState.currentClips[_trimmingClipIndex];
    final screenWidth = MediaQuery.of(context).size.width;

    Duration precedingDuration = Duration.zero;
    for (int i = 0; i < _trimmingClipIndex; i++) {
      precedingDuration += widget.loadedState.currentClips[i].duration;
    }
    final clipStartOffset =
        (precedingDuration.inMilliseconds / 1000) * _pixelsPerSecond;
    final clipWidth =
        (selectedClip.duration.inMilliseconds / 1000) * _pixelsPerSecond;
    final onScreenClipStartX =
        (screenWidth / 2) + clipStartOffset - _scrollController.offset;
    final onScreenClipEndX = onScreenClipStartX + clipWidth;
    final touchX = localPosition.dx;

    if (touchX >= onScreenClipStartX - 20 &&
        touchX <= onScreenClipStartX + 20) {
      _dragType = _DragType.trimStart;
    } else if (touchX >= onScreenClipEndX - 20 &&
        touchX <= onScreenClipEndX + 20) {
      _dragType = _DragType.trimEnd;
    } else {
      _dragType = _DragType.scroll;
    }
  }

  void _handleTrimUpdate(double pixelDelta) {
    final durationDelta = Duration(
      milliseconds: ((pixelDelta / _pixelsPerSecond) * 1000).round(),
    );
    final liveClips =
        widget.loadedState.liveClips ?? widget.loadedState.currentClips;
    final clipToTrim = liveClips[_trimmingClipIndex];

    if (_dragType == _DragType.trimStart) {
      final newStartTime = clipToTrim.startTimeInSource + durationDelta;
      context.read<EditorBloc>().add(
        ClipTrimmed(clipIndex: _trimmingClipIndex, newStart: newStartTime),
      );
      widget.onTrimUpdate(
        clipIndex: _trimmingClipIndex,
        positionInSource: newStartTime,
      );
    } else {
      final newEndTime = clipToTrim.endTimeInSource + durationDelta;
      context.read<EditorBloc>().add(
        ClipTrimmed(clipIndex: _trimmingClipIndex, newEnd: newEndTime),
      );
      widget.onTrimUpdate(
        clipIndex: _trimmingClipIndex,
        positionInSource: newEndTime,
      );
    }

    setState(() {
      final updatedClip = (context.read<EditorBloc>().state as EditorLoaded)
          .liveClips![_trimmingClipIndex];
      _liveTrimDuration = updatedClip.duration;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double clipsWidth =
        (widget.loadedState.videoDuration.inMilliseconds / 1000) *
        _pixelsPerSecond;
    final double marginsWidth = widget.loadedState.currentClips.length * 3.0;
    const double addButtonWidth = 60 + 8;
    final double totalContentWidth = clipsWidth + marginsWidth + addButtonWidth;

    return Expanded(
      child: Stack(
        children: [
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            // We set the behavior to translucent to ensure the GestureDetector
            // captures taps even on empty areas of the container.
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: const Color.fromARGB(255, 34, 34, 34),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalContentWidth + screenWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 30,
                            child: TimeMarkers(
                              totalDuration: widget.loadedState.videoDuration,
                              pixelsPerSecond: _pixelsPerSecond,
                              horizontalPadding: screenWidth / 2,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth / 2,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VideoTimeline(
                                  clips: widget.loadedState.liveCurrentClip,
                                  selectedIndex:
                                      widget.loadedState.selectedClipIndex,
                                  pixelsPerSecond: _pixelsPerSecond,
                                  onClipTapped: (index) => context
                                      .read<EditorBloc>()
                                      .add(ClipTapped(index)),
                                ),
                                if (widget.loadedState.audioClips.isEmpty)
                                  PlaceholderTrack(
                                    icon: Icons.music_note_outlined,
                                    label: 'Add audio',
                                    onTap: () {},
                                  )
                                else
                                  AudioTrackWidget(
                                    audioClips: widget.loadedState.audioClips,
                                    pixelsPerSecond: _pixelsPerSecond,
                                  ),
                                PlaceholderTrack(
                                  icon: Icons.text_fields_outlined,
                                  label: 'Add text',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: widget.positionNotifier,
                    builder: (context, position, child) {
                      return SizedBox(
                        width: 50,
                        child: Playhead(currentTime: _formatDuration(position)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_liveTrimDuration != null && _popupPosition != null)
            Positioned(
              left: _popupPosition!.dx - 25,
              top: _popupPosition!.dy - 110,
              child: _DurationPopup(duration: _liveTrimDuration!),
            ),
        ],
      ),
    );
  }
}

// --- Helper widgets remain unchanged ---
class _DurationPopup extends StatelessWidget {
  final Duration duration;
  const _DurationPopup({required this.duration});

  @override
  Widget build(BuildContext context) {
    final String durationString =
        '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          durationString,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}

class AudioTrackWidget extends StatelessWidget {
  final List<AudioClip> audioClips;
  final double pixelsPerSecond;

  const AudioTrackWidget({
    super.key,
    required this.audioClips,
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: audioClips.map((clip) {
          final clipWidth =
              clip.duration.inMilliseconds / 1000 * pixelsPerSecond;
          return Container(
            width: clipWidth,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.graphic_eq, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Extracted Audio",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
