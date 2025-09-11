import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/presentation/widgets/placeholder_track.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/video_timeline.dart';

class TimelineArea extends StatefulWidget {
  final EditorLoaded loadedState;
  final Function(Duration) onScroll;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const TimelineArea({
    super.key,
    required this.loadedState,
    required this.onScroll,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<TimelineArea> createState() => _TimelineAreaState();
}

enum _DragType { scroll, trimStart, trimEnd, none }

class _TimelineAreaState extends State<TimelineArea> {
  final ScrollController _scrollController = ScrollController();
  static const double pixelsPerSecond = 60.0;
  // --- NEW STATE VARIABLES ---
  _DragType _dragType = _DragType.none;
  int _trimmingClipIndex = -1; // Index of the clip being trimmed
  double _dragStartPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only notify parent if we are not dragging
    if (_dragType == _DragType.none || _dragType == _DragType.scroll) {
      final newPositionMs = (_scrollController.offset / pixelsPerSecond) * 1000;
      widget.onScroll(Duration(milliseconds: newPositionMs.round()));
    }
  }

  @override
  void didUpdateWidget(covariant TimelineArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentPosition = widget.loadedState.videoPosition;
    final totalDuration = widget.loadedState.videoDuration;

    if (currentPosition != oldWidget.loadedState.videoPosition &&
        totalDuration.inMilliseconds > 0 &&
        _scrollController.hasClients) {
      final expectedOffset =
          (currentPosition.inMilliseconds / 1000) * pixelsPerSecond;

      if ((_scrollController.offset - expectedOffset).abs() > 1.0) {
        _scrollController.jumpTo(expectedOffset);
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    widget.onDragStart(); // Pause video playback

    // Check if a clip is selected
    if (widget.loadedState.selectedClipIndex == null) {
      _dragType = _DragType.scroll;
      return;
    }

    _trimmingClipIndex = widget.loadedState.selectedClipIndex!;
    final selectedClip = widget.loadedState.currentClips[_trimmingClipIndex];
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the on-screen start and end positions of the selected clip
    Duration precedingDuration = Duration.zero;
    for (int i = 0; i < _trimmingClipIndex; i++) {
      precedingDuration += widget.loadedState.currentClips[i].duration;
    }
    final clipStartOffset =
        (precedingDuration.inMilliseconds / 1000) * pixelsPerSecond;
    final clipWidth =
        (selectedClip.duration.inMilliseconds / 1000) * pixelsPerSecond;

    final onScreenClipStartX =
        (screenWidth / 2) + clipStartOffset - _scrollController.offset;
    final onScreenClipEndX = onScreenClipStartX + clipWidth;

    // The localPosition is the x-coordinate of the user's finger on the screen
    final touchX = details.localPosition.dx;

    // Check if the touch is on one of the handles (with a generous 40px touch target)
    if (touchX >= onScreenClipStartX - 20 &&
        touchX <= onScreenClipStartX + 20) {
      _dragType = _DragType.trimStart;
      _dragStartPosition = onScreenClipStartX; // Store initial position
    } else if (touchX >= onScreenClipEndX - 20 &&
        touchX <= onScreenClipEndX + 20) {
      _dragType = _DragType.trimEnd;
      _dragStartPosition = onScreenClipEndX; // Store initial position
    } else {
      _dragType = _DragType.scroll;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragType == _DragType.scroll) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final newOffset = (_scrollController.offset - details.delta.dx).clamp(
        0.0,
        maxScroll,
      );
      _scrollController.jumpTo(newOffset);
      return;
    }

    // --- THIS IS THE CORRECTED LOGIC ---
    if (_dragType == _DragType.trimStart || _dragType == _DragType.trimEnd) {
      // 1. Get the pixel change since the last update frame.
      final pixelDelta = details.delta.dx;

      // 2. Convert the pixel change to a duration change.
      final durationDelta = Duration(
        milliseconds: ((pixelDelta / pixelsPerSecond) * 1000).round(),
      );

      // 3. CRITICAL: Read from the continuously updated 'live' state, not the original state.
      final liveClips =
          widget.loadedState.liveClips ?? widget.loadedState.currentClips;
      final clipToTrim = liveClips[_trimmingClipIndex];

      if (_dragType == _DragType.trimStart) {
        // 4. Calculate the new start time by applying the delta to the current live start time.
        final newStartTime = clipToTrim.startTimeInSource + durationDelta;
        context.read<EditorBloc>().add(
          ClipTrimmed(clipIndex: _trimmingClipIndex, newStart: newStartTime),
        );
      } else {
        // _dragType == _DragType.trimEnd
        // 5. Calculate the new end time by applying the delta to the current live end time.
        final newEndTime = clipToTrim.endTimeInSource + durationDelta;
        context.read<EditorBloc>().add(
          ClipTrimmed(clipIndex: _trimmingClipIndex, newEnd: newEndTime),
        );
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    // Always call the onDragEnd callback to resume playback if needed
    widget.onDragEnd();

    // If we were in a trim operation, dispatch the final event to commit
    // the changes from the 'live' state into the official undo/redo history.
    if (_dragType == _DragType.trimStart || _dragType == _DragType.trimEnd) {
      context.read<EditorBloc>().add(ClipTrimEnded());
    }

    // Reset the drag state for the next interaction
    _dragType = _DragType.none;
    _trimmingClipIndex = -1;
    _dragStartPosition = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final double clipsWidth =
        (widget.loadedState.videoDuration.inMilliseconds / 1000) *
        pixelsPerSecond;
    final double marginsWidth = widget.loadedState.currentClips.length * 3.0;
    const double addButtonWidth = 60 + 8;
    final double totalContentWidth = clipsWidth + marginsWidth + addButtonWidth;

    return Expanded(
      child: Container(
        color: const Color.fromARGB(255, 34, 34, 34),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  // Use the new precise width, plus screen width for side padding
                  width: totalContentWidth + screenWidth,
                  height: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 30,
                        width: totalContentWidth + screenWidth,
                        child: TimeMarkers(
                          totalDuration: widget.loadedState.videoDuration,
                          pixelsPerSecond: pixelsPerSecond,
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
                            // --- ROW 1: The Main Video Timeline ---
                            VideoTimeline(
                              clips: widget.loadedState.currentClips,
                              selectedIndex:
                                  widget.loadedState.selectedClipIndex,
                              pixelsPerSecond: pixelsPerSecond,
                              onClipTapped: (index) => context
                                  .read<EditorBloc>()
                                  .add(ClipTapped(index)),
                            ),

                            // --- ROW 2: Placeholder for Audio ---
                            if (widget.loadedState.audioClips.isEmpty)
                              PlaceholderTrack(
                                icon: Icons.music_note_outlined,
                                label: 'Add audio',
                                onTap: () {
                                  // TODO: Implement audio picking logic
                                  print('Add Audio Tapped');
                                },
                              )
                            else
                              AudioTrackWidget(
                                audioClips: widget.loadedState.audioClips,
                                pixelsPerSecond: pixelsPerSecond,
                              ),

                            // --- ROW 3: Placeholder for Text ---
                            PlaceholderTrack(
                              icon: Icons.text_fields_outlined,
                              label: 'Add text',
                              onTap: () {
                                // TODO: Implement text adding logic
                                print('Add Text Tapped');
                              },
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Playhead(
                currentTime: _formatDuration(widget.loadedState.videoPosition),
              ),
            ),
          ],
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
