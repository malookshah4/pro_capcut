import 'package:flutter/material.dart';

class Playhead extends StatelessWidget {
  const Playhead({super.key});

  @override
  Widget build(BuildContext context) {
    // The Playhead is physically static in the center of the screen.
    // It draws a line spanning the full height provided by its parent.
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _PlayheadPainter()),
    );
  }
}

class _PlayheadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;

    // 1. Draw the vertical line (full height)
    canvas.drawRect(
      Rect.fromLTWH(centerX - 1.25, 0, 2.5, size.height),
      linePaint,
    );

    // 2. Draw the Top Handle (Inverted Triangle/Indicator)
    // CapCut style: A small white structure at the very top
    final Path handlePath = Path();
    const double handleWidth = 12.0;
    const double handleHeight = 12.0;

    handlePath.moveTo(centerX - (handleWidth / 2), 0); // Top Left
    handlePath.lineTo(centerX + (handleWidth / 2), 0); // Top Right
    handlePath.lineTo(centerX, handleHeight); // Bottom Tip
    handlePath.close();

    // Draw handle
    canvas.drawPath(handlePath, linePaint);

    // Optional: Add a subtle shadow for better visibility on light clips
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(handlePath, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
