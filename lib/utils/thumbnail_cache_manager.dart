import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:video_compress/video_compress.dart';

class ThumbnailCacheManager {
  static final ThumbnailCacheManager _instance =
      ThumbnailCacheManager._internal();
  factory ThumbnailCacheManager() => _instance;
  ThumbnailCacheManager._internal();

  // Limit cache to prevent OOM
  final int _cacheLimit = 40;
  final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();

  bool _isGenerating = false;
  final List<_ThumbnailRequest> _pendingRequests = [];

  // Track active listeners to deduplicate requests
  final Map<String, List<Completer<Uint8List?>>> _listeners = {};

  Future<Uint8List?> getThumbnail(String videoPath, int timeMs) {
    final String key = "${videoPath}_$timeMs";

    // 1. Check Cache
    if (_memoryCache.containsKey(key)) {
      final data = _memoryCache.remove(key)!;
      _memoryCache[key] = data;
      return Future.value(data);
    }

    final completer = Completer<Uint8List?>();

    // 2. Deduplicate
    if (_listeners.containsKey(key)) {
      _listeners[key]!.add(completer);
      return completer.future;
    }

    // 3. Add New Request
    _listeners[key] = [completer];
    _pendingRequests.add(_ThumbnailRequest(videoPath, timeMs, key));

    // Optimization: Drop oldest pending requests if queue gets huge
    if (_pendingRequests.length > 8) {
      final dropped = _pendingRequests.removeAt(0);
      final waiting = _listeners.remove(dropped.key);
      waiting?.forEach((c) {
        if (!c.isCompleted) c.complete(null);
      });
    }

    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isGenerating) return;
    _isGenerating = true;

    while (_pendingRequests.isNotEmpty) {
      // LIFO: Process newest first so UI feels responsive
      final request = _pendingRequests.removeLast();

      final waitingCompleters = _listeners.remove(request.key);
      if (waitingCompleters == null) continue;

      if (_memoryCache.containsKey(request.key)) {
        final data = _memoryCache[request.key];
        for (var c in waitingCompleters) {
          c.complete(data);
        }
        continue;
      }

      try {
        // GENERATE
        // Reduced quality to 10 to guarantee it works on all devices without OOM
        final Uint8List? bytes = await VideoCompress.getByteThumbnail(
          request.videoPath,
          quality: 10,
          position: request.timeMs,
        );

        if (bytes != null && bytes.isNotEmpty) {
          if (_memoryCache.length >= _cacheLimit) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
          _memoryCache[request.key] = bytes;

          for (var c in waitingCompleters) {
            if (!c.isCompleted) c.complete(bytes);
          }
        } else {
          // Failed or Empty
          for (var c in waitingCompleters) {
            if (!c.isCompleted) c.complete(null);
          }
        }
      } catch (e) {
        print("Thumbnail Error: $e");
        // If MissingPluginException, user needs to restart app completely
        if (e is MissingPluginException) {
          print("CRITICAL: Restart App. Native plugin not attached.");
        }
        for (var c in waitingCompleters) {
          if (!c.isCompleted) c.complete(null);
        }
      }

      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 20));
    }

    _isGenerating = false;
  }

  void clearCache() {
    _memoryCache.clear();
    _pendingRequests.clear();
    _listeners.clear();
    VideoCompress.cancelCompression(); // Stop any active native tasks
    VideoCompress.deleteAllCache();
  }
}

class _ThumbnailRequest {
  final String videoPath;
  final int timeMs;
  final String key;

  _ThumbnailRequest(this.videoPath, this.timeMs, this.key);
}
