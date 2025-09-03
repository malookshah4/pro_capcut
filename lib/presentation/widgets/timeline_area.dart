import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/presentation/widgets/playhead.dart';
import 'package:pro_capcut/presentation/widgets/video_timeline.dart';
import 'package:video_player/video_player.dart';

/// Displays the scrollable timeline and the draggable playhead.
class TimelineArea extends StatelessWidget {
  final VideoPlayerController? controller;
  final EditorLoaded loadedState;
  final ScrollController timelineScrollController;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  // --- REMOVED: No longer needed as we don't concatenate for playback ---
  // final bool isConcatenating;

  const TimelineArea({
    super.key,
    required this.controller,
    required this.loadedState,
    required this.timelineScrollController,
    required this.onDragStart,
    required this.onDragEnd,
    // required this.isConcatenating,
  });

  @override
  Widget build(BuildContext context) {
    final totalDuration = loadedState.videoDuration;

    return Expanded(
      child: Container(
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
                // --- No longer need the isConcatenating check ---
                if (controller != null && controller!.value.isInitialized)
                  VideoTimeline(
                    // --- This now correctly passes the List<VideoClip> ---
                    clips: loadedState.currentClips,
                    videoDuration: controller!.value.duration,
                    selectedIndex: loadedState.selectedClipIndex,
                    onClipTapped: (index) =>
                        context.read<EditorBloc>().add(ClipTapped(index)),
                  )
                else
                  // Show a loader if the controller isn't ready
                  const CircularProgressIndicator(),

                Positioned(
                  top: 0,
                  left: playHeadProgressPosition - (playheadWidth / 2),
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => onDragStart(),
                    onHorizontalDragUpdate: (details) {
                      if (controller == null ||
                          totalDuration.inMilliseconds <= 0) {
                        return;
                      }

                      final newPixelPos =
                          (playHeadProgressPosition + details.delta.dx).clamp(
                            0.0,
                            timelineWidth,
                          );
                      final progress = newPixelPos / timelineWidth;
                      final newTime = totalDuration * progress;

                      // --- MODIFIED: Send a seek request to the BLoC ---
                      // This is better practice than directly controlling the player here
                      context.read<EditorBloc>().add(
                        VideoSeekRequsted(newTime),
                      );
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
      ),
    );
  }
}

/// Formats a Duration into a mm:ss string.
String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}
