import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Haptics

class TrimmingHandles extends StatelessWidget {
  final double pixelsPerSecond;
  final Widget child;
  final Function(double delta) onLeftDrag;
  final Function(double delta) onRightDrag;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const TrimmingHandles({
    super.key,
    required this.pixelsPerSecond,
    required this.child,
    required this.onLeftDrag,
    required this.onRightDrag,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The Clip Content itself (with a border)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: Colors.white, width: 2.0),
          ),
          child: child,
        ),

        // --- Left (Start) Handle ---
        Positioned(
          left: -15, // Increased touch area slightly
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              HapticFeedback.heavyImpact(); // FIX: Explicit "Thud" on grab
              onDragStart();
            },
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragCancel: () => onDragEnd(),
            onHorizontalDragUpdate: (details) {
              onLeftDrag(details.delta.dx);
            },
            child: Container(
              width: 30, // Larger Hitbox
              alignment: Alignment.center,
              child: Container(
                // Visual Handle
                width: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.black,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
        ),

        // --- Right (End) Handle ---
        Positioned(
          right: -15, // Increased touch area slightly
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              HapticFeedback.heavyImpact(); // FIX: Explicit "Thud" on grab
              onDragStart();
            },
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragCancel: () => onDragEnd(),
            onHorizontalDragUpdate: (details) {
              onRightDrag(details.delta.dx);
            },
            child: Container(
              width: 30, // Larger Hitbox
              alignment: Alignment.center,
              child: Container(
                // Visual Handle
                width: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.black,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
