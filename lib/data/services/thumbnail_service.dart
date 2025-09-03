// lib/data/services/thumbnail_service.dart
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';

class ThumbnailService {
  // The cache holds the generated thumbnails, with the video path as the key.
  static final Map<String, List<Uint8List?>> _cache = {};

  // The number of thumbnails to generate per clip.
  static const int _thumbnailCount = 5;

  static Future<List<Uint8List?>> getThumbnails(String videoPath) async {
    // If thumbnails are already in the cache, return them immediately.
    if (_cache.containsKey(videoPath)) {
      return _cache[videoPath]!;
    }

    // Otherwise, generate, cache, and then return them.
    try {
      final List<Uint8List?> generatedThumbnails = [];
      final mediaInfo = await VideoCompress.getMediaInfo(videoPath);
      final durationMs = (mediaInfo.duration ?? 0) * 1000;

      if (durationMs <= 0) {
        // Cache an empty list for invalid videos to avoid re-processing.
        _cache[videoPath] = [];
        return [];
      }

      final intervalMs = durationMs / _thumbnailCount;

      for (int i = 0; i < _thumbnailCount; i++) {
        final timeMs = (i * intervalMs).toInt();
        final thumbnailBytes = await VideoCompress.getByteThumbnail(
          videoPath,
          quality: 20,
          position: timeMs,
        );
        generatedThumbnails.add(thumbnailBytes);
      }

      // Store the newly generated thumbnails in the cache.
      _cache[videoPath] = generatedThumbnails;
      return generatedThumbnails;
    } catch (e) {
      // If generation fails, cache a null and return an empty list.
      _cache[videoPath] = [];
      return [];
    }
  }
}
