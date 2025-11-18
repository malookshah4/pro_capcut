import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Haptics
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/trimming_handles.dart';

class TimelineTrackWidget extends StatelessWidget {
  final EditorTrack track;
  final double pixelsPerSecond;
  final double horizontalPadding;
  final String? selectedClipId;
  final Function(String trackId, String clipId) onClipTapped;
  final VoidCallback? onTrimStart;
  final VoidCallback? onTrimEnd;

  final VoidCallback? onMoveStart;
  final Function(String clipId, double deltaPixels, DragUpdateDetails details)?
  onMoveUpdate;
  final VoidCallback? onMoveEnd;

  const TimelineTrackWidget({
    super.key,
    required this.track,
    required this.pixelsPerSecond,
    required this.horizontalPadding,
    this.selectedClipId,
    required this.onClipTapped,
    this.onTrimStart,
    this.onTrimEnd,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
  });

  @override
  Widget build(BuildContext context) {
    final List<TimelineClip> normalClips = [];
    TimelineClip? selectedClip;

    for (var clip in track.clips) {
      final tClip = clip as TimelineClip;
      if (tClip.id == selectedClipId) {
        selectedClip = tClip;
      } else {
        normalClips.add(tClip);
      }
    }

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TrackLabel(track: track),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ...normalClips
                    .map((clip) => _buildClipWidget(context, clip))
                    .toList(),
                if (selectedClip != null)
                  _buildClipWidget(context, selectedClip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipWidget(BuildContext context, TimelineClip clip) {
    final double left =
        (clip.startTimeInTimelineInMicroseconds / 1000000.0) * pixelsPerSecond;
    final double width =
        (clip.durationInMicroseconds / 1000000.0) * pixelsPerSecond;
    final bool isSelected = clip.id == selectedClipId;

    Widget child;
    if (clip is VideoClip) {
      child = _VideoClipWidget(clip: clip);
    } else if (clip is AudioClip) {
      child = _AudioClipWidget(clip: clip);
    } else if (clip is TextClip) {
      child = _TextClipWidget(clip: clip);
    } else {
      child = Container(color: Colors.red);
    }

    // --- GESTURE WRAPPER FOR BODY ---
    Widget bodyContent = _ClipGestureHandler(
      trackType: track.type,
      isSelected: isSelected,
      onTap: () => onClipTapped(track.id, clip.id),
      onMoveStart: onMoveStart,
      onMoveUpdate: (delta, details) =>
          onMoveUpdate?.call(clip.id, delta, details),
      onMoveEnd: onMoveEnd,
      child: child,
    );

    void handleTrim(double pixelDelta, bool isStart) {
      final double deltaSeconds = pixelDelta / pixelsPerSecond;
      final int deltaMicroseconds = (deltaSeconds * 1000000).round();

      context.read<EditorBloc>().add(
        ClipTrimRequested(
          trackId: track.id,
          clipId: clip.id,
          delta: Duration(microseconds: deltaMicroseconds),
          isStartHandle: isStart,
        ),
      );
    }

    return Positioned(
      left: left,
      width: width,
      height: 50,
      top: 5,
      child: isSelected
          ? TrimmingHandles(
              pixelsPerSecond: pixelsPerSecond,
              onLeftDrag: (delta) => handleTrim(delta, true),
              onRightDrag: (delta) => handleTrim(delta, false),
              onDragStart: () {
                HapticFeedback.lightImpact();
                onTrimStart?.call();
              },
              onDragEnd: () => onTrimEnd?.call(),
              child: bodyContent,
            )
          : Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
              child: bodyContent,
            ),
    );
  }
}

// --- NEW: Stateful Widget using "LongPressMoveUpdate" ---
class _ClipGestureHandler extends StatefulWidget {
  final TrackType trackType;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onMoveStart;
  final Function(double, DragUpdateDetails)? onMoveUpdate;
  final VoidCallback? onMoveEnd;
  final Widget child;

  const _ClipGestureHandler({
    required this.trackType,
    required this.isSelected,
    required this.onTap,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    required this.child,
  });

  @override
  State<_ClipGestureHandler> createState() => _ClipGestureHandlerState();
}

class _ClipGestureHandlerState extends State<_ClipGestureHandler> {
  bool _isDragging = false;
  double _lastGlobalX = 0.0; // To calculate manual delta

  void _endDrag() {
    if (_isDragging) {
      setState(() => _isDragging = false);
      widget.onMoveEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If it's the main video track, we only want Tap logic, no drag.
    if (widget.trackType == TrackType.video) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }

    // For Overlay/Audio/Text, we enable "Long Press -> Move" without lifting
    return GestureDetector(
      onTap: widget.onTap,

      // 1. Long Press Start: Vibration + Lock
      onLongPressStart: (details) {
        HapticFeedback.heavyImpact(); // "Thud"
        setState(() {
          _isDragging = true;
          _lastGlobalX = details.globalPosition.dx;
        });
        // Select the clip if not selected
        if (!widget.isSelected) {
          widget.onTap();
        }
        widget.onMoveStart?.call();
      },

      // 2. Move Update (Continues without lifting finger)
      onLongPressMoveUpdate: (details) {
        if (_isDragging) {
          final double currentGlobalX = details.globalPosition.dx;
          final double delta = currentGlobalX - _lastGlobalX;

          // Update last position for next frame
          _lastGlobalX = currentGlobalX;

          // Construct a DragUpdateDetails to keep parent logic compatible
          // (The parent uses details for auto-scrolling based on global position)
          final dragDetails = DragUpdateDetails(
            globalPosition: details.globalPosition,
            localPosition: details.localPosition,
            delta: Offset(delta, 0),
            primaryDelta: delta,
          );

          widget.onMoveUpdate?.call(delta, dragDetails);
        }
      },

      // 3. Release (Unlock)
      onLongPressEnd: (_) => _endDrag(),
      onLongPressUp: () => _endDrag(),
      onLongPressCancel: () => _endDrag(),

      // Visual Feedback
      child: Opacity(opacity: _isDragging ? 0.7 : 1.0, child: widget.child),
    );
  }
}

// --- Helper Widgets ---
class _VideoClipWidget extends StatelessWidget {
  final VideoClip clip;
  const _VideoClipWidget({required this.clip});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const Center(
          child: Icon(Icons.movie_creation, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _AudioClipWidget extends StatelessWidget {
  final AudioClip clip;
  const _AudioClipWidget({required this.clip});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Audio",
              style: TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextClipWidget extends StatelessWidget {
  final TextClip clip;
  const _TextClipWidget({required this.clip});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              clip.text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final EditorTrack track;
  const _TrackLabel({required this.track});
  @override
  Widget build(BuildContext context) {
    if (track.type == TrackType.video) return const SizedBox.shrink();
    return Container(
      width: 60,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            track.locked ? Icons.lock : Icons.lock_open,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(height: 4),
          Icon(
            track.visible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}
