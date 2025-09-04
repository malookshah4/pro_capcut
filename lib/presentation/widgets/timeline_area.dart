import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
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

class _TimelineAreaState extends State<TimelineArea> {
  final ScrollController _scrollController = ScrollController();
  static const double pixelsPerSecond = 60.0;

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
    final newPositionMs = (_scrollController.offset / pixelsPerSecond) * 1000;
    widget.onScroll(Duration(milliseconds: newPositionMs.round()));
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // --- FIX: Calculate the total width precisely ---
    // 1. Width of all video clips based on their duration
    final double clipsWidth =
        (widget.loadedState.videoDuration.inMilliseconds / 1000) *
        pixelsPerSecond;
    // 2. Width of the margins between each clip (1.5 on each side)
    final double marginsWidth = widget.loadedState.currentClips.length * 3.0;
    // 3. Width of the add button and its padding
    const double addButtonWidth = 60 + 8; // button width + horizontal padding
    // 4. The final, precise total width of the timeline's content
    final double totalContentWidth = clipsWidth + marginsWidth + addButtonWidth;

    return Expanded(
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onHorizontalDragStart: (_) => widget.onDragStart(),
              onHorizontalDragEnd: (_) => widget.onDragEnd(),
              onHorizontalDragUpdate: (details) {
                final maxScroll = _scrollController.position.maxScrollExtent;
                final newOffset = (_scrollController.offset - details.delta.dx)
                    .clamp(0.0, maxScroll);
                _scrollController.jumpTo(newOffset);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  // Use the new precise width, plus screen width for side padding
                  width: totalContentWidth + screenWidth,
                  height: double.infinity,
                  child: Column(
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
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth / 2,
                        ),
                        child: VideoTimeline(
                          clips: widget.loadedState.currentClips,
                          selectedIndex: widget.loadedState.selectedClipIndex,
                          pixelsPerSecond: pixelsPerSecond,
                          onClipTapped: (index) =>
                              context.read<EditorBloc>().add(ClipTapped(index)),
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
