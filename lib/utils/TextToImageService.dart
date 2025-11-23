import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TextToImageService {
  Future<String?> generateImageFromText(dynamic textClip) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final double scale = 3.0;

      // 1. SAFER Property Access
      // Use dynamic to bypass type checks if you aren't importing the specific model here
      final dynamic style = (textClip as dynamic).style;

      // Default values
      double fontSize = 30.0;
      Color color = Colors.white;
      String fontFamily = "Roboto";

      // Check properties on the style object dynamically
      if (style != null) {
        try {
          fontSize = (style.fontSize as num).toDouble();
        } catch (_) {}
        try {
          color = style.color as Color;
        } catch (_) {}
        try {
          fontFamily = style.fontFamily as String;
        } catch (_) {}
      }

      final textStyle = TextStyle(
        fontSize: fontSize * scale,
        color: color,
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
      );

      final textSpan = TextSpan(text: textClip.text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();

      // 2. Draw with padding
      final width = (textPainter.width + 40).toInt();
      final height = (textPainter.height + 40).toInt();

      // Draw
      textPainter.paint(canvas, const Offset(20, 20));

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final dir = await getTemporaryDirectory();
      // Unique name prevents cache conflicts
      final fileName =
          "text_${textClip.id}_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file.path;
    } catch (e) {
      print("Text Gen Error: $e");
      return null;
    }
  }
}
