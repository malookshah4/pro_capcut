import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';

class TextPreviewLayer extends StatelessWidget {
  final Duration currentTime;

  const TextPreviewLayer({super.key, required this.currentTime});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorBloc>().state;
    if (state is! EditorLoaded) return const SizedBox.shrink();

    // 1. Get Active Clips
    final List<Map<String, dynamic>> activeTextItems = [];
    for (final track in state.project.tracks) {
      if (track.type == TrackType.text) {
        for (final clip in track.clips) {
          if (clip is TextClip) {
            if (currentTime >= clip.startTime && currentTime < clip.endTime) {
              activeTextItems.add({'clip': clip, 'trackId': track.id});
            }
          }
        }
      }
    }

    // 2. Render
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: activeTextItems.map((item) {
            final TextClip clip = item['clip'];
            final String trackId = item['trackId'];

            return _InteractiveTextOverlay(
              key: ValueKey(clip.id),
              clip: clip,
              trackId: trackId,
              viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
              isSelected: state.selectedClipId == clip.id,
            );
          }).toList(),
        );
      },
    );
  }
}

class _InteractiveTextOverlay extends StatefulWidget {
  final TextClip clip;
  final String trackId;
  final Size viewportSize;
  final bool isSelected;

  const _InteractiveTextOverlay({
    super.key,
    required this.clip,
    required this.trackId,
    required this.viewportSize,
    required this.isSelected,
  });

  @override
  State<_InteractiveTextOverlay> createState() =>
      _InteractiveTextOverlayState();
}

class _InteractiveTextOverlayState extends State<_InteractiveTextOverlay> {
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _baseOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = widget.clip.scale;
    _baseRotation = widget.clip.rotation;
    _startFocalPoint = details.focalPoint;

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

    final double normX = newPosPixels.dx / widget.viewportSize.width;
    final double normY = newPosPixels.dy / widget.viewportSize.height;

    // Limit minimum scale to prevent it from disappearing entirely
    final double rawNewScale = _baseScale * details.scale;
    final double newScale = rawNewScale < 0.15 ? 0.15 : rawNewScale;

    final newRotation = _baseRotation + details.rotation;

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
    final alignX = (widget.clip.offsetX - 0.5) * 2;
    final alignY = (widget.clip.offsetY - 0.5) * 2;

    // --- DYNAMIC PADDING CALCULATION ---
    // This is the fix. We want a constant "touch area" of ~30px around the text,
    // regardless of how small the text is scaled.
    // If scale is 1.0, padding is 30.
    // If scale is 0.1, padding is 300. (300 * 0.1 = 30px visual space).
    final safeScale = widget.clip.scale < 0.1 ? 0.1 : widget.clip.scale;
    final double inversePadding = 60.0 / safeScale;

    // We also scale the border thickness and handle size inversely
    // so they don't look thick when zoomed out or thin when zoomed in.
    final double borderThickness = 1.5 / safeScale;
    final double handleSize = 10.0 / safeScale;

    return Align(
      alignment: Alignment(alignX, alignY),
      child: GestureDetector(
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
              // 1. The Transparent Hit-Box (Dynamic Padding)
              padding: EdgeInsets.all(inversePadding),
              color: Colors.transparent, // Must be transparent to catch hits
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 2. The Visible Selection Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: borderThickness,
                            ),
                            borderRadius: BorderRadius.circular(4 / safeScale),
                          )
                        : null,
                    child: Text(
                      widget.clip.text,
                      textAlign: TextAlign.center,
                      style: widget.clip.style.toFlutterTextStyle(),
                    ),
                  ),

                  // 3. The Visual Corner Handles (Only if selected)
                  if (widget.isSelected) ...[
                    // Top-Left
                    Positioned(
                      left: -handleSize / 2,
                      top: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    // Top-Right
                    Positioned(
                      right: -handleSize / 2,
                      top: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    // Bottom-Left
                    Positioned(
                      left: -handleSize / 2,
                      bottom: -handleSize / 2,
                      child: _CornerHandle(size: handleSize),
                    ),
                    // Bottom-Right
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
