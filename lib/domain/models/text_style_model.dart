import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'text_style_model.g.dart';

@HiveType(typeId: 7)
class TextStyleModel extends HiveObject {
  @HiveField(0)
  final String fontName;

  @HiveField(1)
  final double fontSize;

  @HiveField(2)
  final int primaryColor;

  @HiveField(3)
  final int strokeColor;

  @HiveField(4)
  final double strokeWidth;

  TextStyleModel({
    this.fontName = 'System',
    this.fontSize = 32.0,
    this.primaryColor = 0xFFFFFFFF,
    this.strokeColor = 0x00000000,
    this.strokeWidth = 0.0,
  });

  TextStyle toFlutterTextStyle() {
    // Simple font mapping for now.
    // In a real app, map 'Rubik' to GoogleFonts.rubik(), etc.
    String? fontFamily;
    if (fontName != 'System') {
      // If you had font assets declared in pubspec.yaml, you'd use them here.
      // For now, we fall back to system font but allow the logic to exist.
      fontFamily = null;
    }

    TextStyle style = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: Color(primaryColor),
      fontWeight: FontWeight.bold, // Default bold for visibility
      shadows: [
        // Add a default drop shadow so white text is visible on white video
        const Shadow(
          offset: Offset(1, 1),
          blurRadius: 3.0,
          color: Colors.black54,
        ),
      ],
    );

    if (strokeWidth > 0) {
      return style.copyWith(
        shadows: [
          Shadow(
            offset: Offset(-strokeWidth, -strokeWidth),
            color: Color(strokeColor),
          ),
          Shadow(
            offset: Offset(strokeWidth, -strokeWidth),
            color: Color(strokeColor),
          ),
          Shadow(
            offset: Offset(strokeWidth, strokeWidth),
            color: Color(strokeColor),
          ),
          Shadow(
            offset: Offset(-strokeWidth, strokeWidth),
            color: Color(strokeColor),
          ),
        ],
      );
    }
    return style;
  }
}
