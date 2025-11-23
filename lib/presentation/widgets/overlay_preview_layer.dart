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
              aspectRatio: controller.value.aspectRatio,
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
  final double aspectRatio;
  final Widget child;

  const _InteractiveOverlay({
    super.key,
    required this.clip,
    required this.trackId,
    required this.viewportSize,
    required this.isSelected,
    required this.aspectRatio,
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

    // Calculate current pixel position from normalized (0.0 - 1.0)
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

    // Normalize back to 0.0 - 1.0
    final double normX = newPosPixels.dx / widget.viewportSize.width;
    final double normY = newPosPixels.dy / widget.viewportSize.height;

    double newScale = _baseScale * details.scale;
    if (newScale < 0.15) newScale = 0.15;

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
    // Align uses -1.0 to 1.0, we store 0.0 to 1.0
    final alignX = (widget.clip.offsetX - 0.5) * 2;
    final alignY = (widget.clip.offsetY - 0.5) * 2;

    // Padding increases as video gets smaller so it's easier to grab
    final safeScale = widget.clip.scale < 0.1 ? 0.1 : widget.clip.scale;
    final double inversePadding = 20.0 / safeScale;
    final double handleSize = 12.0 / safeScale;
    final double borderThickness = 2.0 / safeScale;

    final double baseWidth = widget.viewportSize.width * 0.5;

    return Align(
      alignment: Alignment(alignX, alignY),
      child: GestureDetector(
        // CRITICAL: Allows dragging on transparent padding area
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
                  Container(
                    width: baseWidth,
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: borderThickness,
                            ),
                          )
                        : null,
                    child: AspectRatio(
                      aspectRatio: widget.aspectRatio,
                      child: widget.child,
                    ),
                  ),

                  if (widget.isSelected) ...[
                    Positioned(
                      left: -handleSize / 2,
                      top: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    Positioned(
                      right: -handleSize / 2,
                      top: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    Positioned(
                      left: -handleSize / 2,
                      bottom: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    Positioned(
                      right: -handleSize / 2,
                      bottom: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerHandle extends StatelessWidget {
  final double size;
  const _CornerHandle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
    );
  }
}
