import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/video_timeline.dart';

class TimelineArea extends StatelessWidget {
  final EditorLoaded loadedState;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  // FIX: This widget now requires onDragUpdate to send data back to the parent
  final void Function(Duration newPosition) onDragUpdate;

  const TimelineArea({
    super.key,
    required this.loadedState,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: Calculate total duration from the accurate BLoC state
    final totalDuration = loadedState.videoDuration;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final timelineWidth = constraints.maxWidth;
          const double playheadWidth = 50.0;

          double playHeadProgressPosition = 0.0;
          if (totalDuration.inMilliseconds > 0) {
            playHeadProgressPosition =
                (loadedState.videoPosition.inMilliseconds /
                    totalDuration.inMilliseconds) *
                timelineWidth;
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              VideoTimeline(
                clips: loadedState.currentClips,
                videoDuration: totalDuration,
                selectedIndex: loadedState.selectedClipIndex,
                onClipTapped: (index) =>
                    context.read<EditorBloc>().add(ClipTapped(index)),
              ),
              Positioned(
                top: 0,
                left: playHeadProgressPosition - (playheadWidth / 2),
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => onDragStart(),
                  onHorizontalDragUpdate: (details) {
                    if (totalDuration.inMilliseconds <= 0) return;

                    final newPixelPos =
                        (playHeadProgressPosition + details.delta.dx).clamp(
                          0.0,
                          timelineWidth,
                        );

                    final progress = newPixelPos / timelineWidth;
                    final newTime = totalDuration * progress;

                    // FIX: Use the callback to notify the parent of the drag update
                    onDragUpdate(newTime);
                  },
                  onHorizontalDragEnd: (_) => onDragEnd(),
                  child: SizedBox(
                    width: playheadWidth,
                    child: Playhead(
                      currentTime: _formatDuration(loadedState.videoPosition),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}
