import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:video_compress/video_compress.dart';

class VideoTimelineStrip extends StatelessWidget {
  final VideoClip clip;
  final double clipWidth;
  final double clipHeight;

  const VideoTimelineStrip({
    super.key,
    required this.clip,
    required this.clipWidth,
    required this.clipHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (clipWidth <= 0) return const SizedBox.shrink();

    // --- STRATEGY 1: LOAD SAVED FILE (FASTEST) ---
    if (clip.thumbnailPath != null) {
      final file = File(clip.thumbnailPath!);
      if (file.existsSync()) {
        return ClipRRect(
          child: Container(
            width: clipWidth,
            height: clipHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              image: DecorationImage(
                image: ResizeImage(
                  FileImage(file),
                  height: 100, // Decode small to save RAM
                  policy: ResizeImagePolicy.fit,
                ),
                // Tile the single image horizontally
                repeat: ImageRepeat.repeatX,
                alignment: Alignment.centerLeft,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),
        );
      }
    }

    // --- STRATEGY 2: DYNAMIC FALLBACK (IF FILE MISSING) ---
    // This handles old clips or deleted cache files by generating
    // the thumbnail in memory right now.
    return _DynamicFallbackStrip(
      videoPath: clip.sourcePath,
      clipWidth: clipWidth,
      clipHeight: clipHeight,
    );
  }
}

class _DynamicFallbackStrip extends StatefulWidget {
  final String videoPath;
  final double clipWidth;
  final double clipHeight;

  const _DynamicFallbackStrip({
    required this.videoPath,
    required this.clipWidth,
    required this.clipHeight,
  });

  @override
  State<_DynamicFallbackStrip> createState() => _DynamicFallbackStripState();
}

class _DynamicFallbackStripState extends State<_DynamicFallbackStrip> {
  Uint8List? _bytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateInMemory();
  }

  Future<void> _generateInMemory() async {
    try {
      // Generate 1 low-quality frame from the start
      final bytes = await VideoCompress.getByteThumbnail(
        widget.videoPath,
        quality: 15,
        position: 0, // Start of video
      );

      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Fallback thumbnail failed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.clipWidth,
        height: widget.clipHeight,
        color: const Color(0xFF1C1C1C),
      );
    }

    if (_bytes == null) {
      // If generation truly fails (corrupt video), show error
      return Container(
        width: widget.clipWidth,
        height: widget.clipHeight,
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white24, size: 16),
        ),
      );
    }

    return ClipRRect(
      child: Container(
        width: widget.clipWidth,
        height: widget.clipHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          image: DecorationImage(
            image: ResizeImage(
              MemoryImage(_bytes!),
              height: 100,
              policy: ResizeImagePolicy.fit,
            ),
            repeat: ImageRepeat.repeatX, // Tile it
            alignment: Alignment.centerLeft,
            fit: BoxFit.fitHeight,
          ),
        ),
      ),
    );
  }
}
