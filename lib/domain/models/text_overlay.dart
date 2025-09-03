// In lib/domain/models/text_overlay.dart
import 'package:flutter/material.dart';

class TextOverlay {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final Alignment position;
  // We can add more properties like color, fontSize, etc. later

  TextOverlay({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.position,
  });
}
