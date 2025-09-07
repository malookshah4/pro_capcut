import 'package:flutter/material.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';

class TrimmingHandles extends StatelessWidget {
  final VideoClip clip;
  final int clipIndex;
  final double pixelsPerSecond;

  const TrimmingHandles({
    super.key,
    required this.clip,
    required this.clipIndex,
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.0),
                  border: Border.all(color: Colors.white, width: 2.0),
                ),
              ),
            ),

            // --- Left (Start) Handle ---
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              // VVVVVV ADD GESTUREDETECTOR VVVVVV
              child: Container(
                // Transparent container to increase touch target size
                color: Colors.transparent,
                width: 20, // Larger width for easier grabbing
                alignment: Alignment.centerLeft,
                child: Container(
                  // This is the visible part of the handle
                  width: 10,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.menu, color: Colors.black, size: 8),
                  ),
                ),
              ),
            ),

            // --- Right (End) Handle ---
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              // VVVVVV ADD GESTUREDETECTOR VVVVVV
              child: Container(
                // Transparent container to increase touch target size
                color: Colors.transparent,
                width: 20, // Larger width for easier grabbing
                alignment: Alignment.centerRight,
                child: Container(
                  // This is the visible part of the handle
                  width: 10,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.menu, color: Colors.black, size: 8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
