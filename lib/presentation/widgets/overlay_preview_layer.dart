import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/utils/PlaybackCoordinator.dart';
import 'package:video_player/video_player.dart';

class OverlayPreviewLayer extends StatelessWidget {
  final Duration currentTime;
  final PlaybackCoordinator coordinator;
  const OverlayPreviewLayer({
    super.key,
    required this.currentTime,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorBloc>().state;
    if (state is! EditorLoaded) return const SizedBox.shrink();
    final List<Map<String, dynamic>> activeOverlays = [];

    for (final track in state.project.tracks) {
      if (track.type == TrackType.overlay) {
        for (final clip in track.clips) {
          if (clip is VideoClip) {
            if (currentTime >= clip.startTime && currentTime < clip.endTime) {
              activeOverlays.add({'clip': clip, 'trackId': track.id});
            }
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: activeOverlays.map((item) {
            final VideoClip clip = item['clip'];
            final String trackId = item['trackId'];

            final controller = coordinator.getOverlayController(clip.id);

            if (controller == null || !controller.value.isInitialized) {
              return const SizedBox.shrink();
            }

            return _InteractiveOverlay(
              key: ValueKey(clip.id),
              clip: clip,
              trackId: trackId,
              viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
              isSelected: state.selectedClipId == clip.id,
              // Pass the REAL video aspect ratio
              nativeAspectRatio: controller.value.aspectRatio,
              // Pass the REAL video size for FittedBox
              videoSize: controller.value.size,
              child: VideoPlayer(controller),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InteractiveOverlay extends StatefulWidget {
  final VideoClip clip;
  final String trackId;
  final Size viewportSize;
  final bool isSelected;
  final double nativeAspectRatio;
  final Size videoSize;
  final Widget child;

  const _InteractiveOverlay({
    super.key,
    required this.clip,
    required this.trackId,
    required this.viewportSize,
    required this.isSelected,
    required this.nativeAspectRatio,
    required this.videoSize,
    required this.child,
  });

  @override
  State<_InteractiveOverlay> createState() => _InteractiveOverlayState();
}

class _InteractiveOverlayState extends State<_InteractiveOverlay> {
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _baseOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = widget.clip.scale;
    _baseRotation = widget.clip.rotation;
    _startFocalPoint = details.focalPoint;

    // Calculate relative to the CANVAS size, not the screen
    _baseOffset = Offset(
      widget.clip.offsetX * widget.viewportSize.width,
      widget.clip.offsetY * widget.viewportSize.height,
    );

    if (!widget.isSelected) {
      context.read<EditorBloc>().add(
        ClipTapped(trackId: widget.trackId, clipId: widget.clip.id),
      );
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final Offset deltaPixel = details.focalPoint - _startFocalPoint;
    final Offset newPosPixels = _baseOffset + deltaPixel;

    // Normalize position (0.0 - 1.0) relative to the current Canvas Size
    final double normX = newPosPixels.dx / widget.viewportSize.width;
    final double normY = newPosPixels.dy / widget.viewportSize.height;

    double newScale = _baseScale * details.scale;
    if (newScale < 0.1) newScale = 0.1; // Min size limit
    final double newRotation = _baseRotation + details.rotation;

    context.read<EditorBloc>().add(
      ClipTransformUpdated(
        trackId: widget.trackId,
        clipId: widget.clip.id,
        offsetX: normX,
        offsetY: normY,
        scale: newScale,
        rotation: newRotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    context.read<EditorBloc>().add(EditorProjectSaved());
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Alignment (-1.0 to 1.0)
    final alignX = (widget.clip.offsetX - 0.5) * 2;
    final alignY = (widget.clip.offsetY - 0.5) * 2;

    // 2. Handle Sizes
    // Scale handle sizes inversely so they stay constant visual size
    final safeScale = widget.clip.scale < 0.1 ? 0.1 : widget.clip.scale;
    final double inversePadding = 20.0 / safeScale;
    final double handleSize = 12.0 / safeScale;
    final double borderThickness = 2.0 / safeScale;

    // 3. Determine Base Width (Relative to Canvas Width)
    // This ensures if Canvas shrinks, Overlay shrinks visually (50->40 behavior)
    final double baseWidth = widget.viewportSize.width * 0.5;

    return Align(
      alignment: Alignment(alignX, alignY),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          context.read<EditorBloc>().add(
            ClipTapped(trackId: widget.trackId, clipId: widget.clip.id),
          );
        },
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: widget.clip.rotation,
          child: Transform.scale(
            scale: widget.clip.scale,
            child: Container(
              color: Colors.transparent, // Hitbox
              padding: EdgeInsets.all(inversePadding),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // --- THE ANTI-STRETCH FIX ---
                  Container(
                    width: baseWidth,
                    // We don't set height; AspectRatio controls it
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: borderThickness,
                            ),
                          )
                        : null,
                    child: AspectRatio(
                      // Force the container to match the video's aspect ratio
                      aspectRatio: widget.nativeAspectRatio,
                      // FittedBox ensures the video content NEVER distorts
                      // even if rounding errors occur.
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: widget.videoSize.width,
                          height: widget.videoSize.height,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),

                  // Handles
                  if (widget.isSelected) ...[
                    _buildHandle(
                      -handleSize / 2,
                      -handleSize / 2,
                      handleSize,
                    ), // Top-Left
                    _buildHandle(
                      null,
                      -handleSize / 2,
                      handleSize,
                      right: -handleSize / 2,
                    ), // Top-Right
                    _buildHandle(
                      -handleSize / 2,
                      null,
                      handleSize,
                      bottom: -handleSize / 2,
                    ), // Bottom-Left
                    _buildHandle(
                      null,
                      null,
                      handleSize,
                      right: -handleSize / 2,
                      bottom: -handleSize / 2,
                    ), // Bottom-Right
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Positioned _buildHandle(
    double? left,
    double? top,
    double size, {
    double? right,
    double? bottom,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }
}
