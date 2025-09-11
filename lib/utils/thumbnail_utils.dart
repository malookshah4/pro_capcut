import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

class ThumbnailUtils {
  /// Generates a thumbnail from a video path and saves it to a unique file path.
  static Future<String?> generateAndSaveThumbnail(
    String videoPath,
    String uniqueId,
  ) async {
    try {
      final thumbnailBytes = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 30,
      );

      if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
        // ✨ FIX: Use getTemporaryDirectory() to save to the app's cache.
        final dir = await getTemporaryDirectory();
        final thumbnailPath = '${dir.path}/thumb_$uniqueId.jpg';
        final file = File(thumbnailPath);
        await file.writeAsBytes(thumbnailBytes, flush: true);
        print("Thumbnail generated at: $thumbnailPath");
        return thumbnailPath;
      }
    } catch (e) {
      print("Error generating thumbnail: $e");
    }
    return null;
  }

  /// Safely deletes a thumbnail file if it exists.
  static Future<void> deleteThumbnail(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print("Deleted old thumbnail: $path");
      }
    } catch (e) {
      print("Error deleting old thumbnail: $e");
    }
  }
}
